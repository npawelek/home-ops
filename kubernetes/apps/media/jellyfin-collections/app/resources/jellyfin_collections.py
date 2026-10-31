#!/usr/bin/env python3
import argparse
import hashlib
import http.server
import json
import os
import re
import signal
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field

CONFIG_PATH = os.environ.get("CONFIG_PATH", "/app/config.json")
CACHE_PATH = os.environ.get("MODEL_CACHE_PATH", "/tmp/model-cache.json")
CATEGORIES = ("kids", "shorts", "christmas", "halloween")
HOLIDAYS = ("christmas", "halloween")
SYSTEM_PROMPT = (
  "You help sort movies in a family media library. You get facts about one movie and one yes/no question."
)


def log(msg):
  print(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} {msg}", file=sys.stderr, flush=True)


def load_config() -> dict:
  with open(CONFIG_PATH) as f:
    return json.load(f)


def env_bool(name, default="true"):
  return os.environ.get(name, default).strip().lower() in ("1", "true", "yes")


class Http:
  def __init__(self, base, headers):
    self.base = base.rstrip("/")
    self.headers = headers

  def request(self, method, path, params=None, body=None, timeout=120):
    url = self.base + path
    if params:
      url += "?" + urllib.parse.urlencode(params, doseq=True)
    headers = {**self.headers, "Accept": "application/json"}
    data = None
    if body is not None:
      data = json.dumps(body).encode()
      headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as r:
      raw = r.read()
    return json.loads(raw) if raw else None

  def get(self, path, **params):
    return self.request("GET", path, params)


class Jellyfin(Http):
  def __init__(self):
    super().__init__(
      os.environ.get("JELLYFIN_URL", "http://jellyfin.media.svc.cluster.local:8096"),
      {"Authorization": f'MediaBrowser Token="{os.environ["JELLYFIN_API_KEY"]}"'},
    )
    users = [u for u in self.get("/Users") if u["Policy"].get("IsAdministrator") and not u["Policy"].get("IsDisabled")]
    if not users:
      raise SystemExit("no enabled Jellyfin administrator to read collections through")
    users.sort(key=lambda u: (not u["Policy"].get("EnableAllFolders"), u["Name"]))
    self.user_id = users[0]["Id"]
    self.user_name = users[0]["Name"]
    self.all_folders = bool(users[0]["Policy"].get("EnableAllFolders"))

  def items(self, **params):
    out, start = [], 0
    while True:
      page = self.get("/Items", userId=self.user_id, StartIndex=start, Limit=500, **params)
      out += page.get("Items", [])
      start += 500
      if start >= page.get("TotalRecordCount", 0):
        return out


class Radarr(Http):
  def __init__(self, name):
    prefix = name.upper().replace("-", "_")
    super().__init__(
      os.environ.get(f"{prefix}_URL", f"http://{name}.downloads.svc.cluster.local:7878"),
      {"X-Api-Key": os.environ[f"{prefix}_APIKEY"]},
    )
    self.name = name
    labels = {t["id"]: t["label"] for t in self.get("/api/v3/tag")}
    self.movies = {}
    for m in self.get("/api/v3/movie"):
      m["_tags"] = {labels.get(t, str(t)) for t in m.get("tags", [])}
      self.movies[str(m["tmdbId"])] = m


@dataclass
class Verdict:
  value: bool | None
  source: str
  detail: str
  flag: str = ""

  def text(self, cat):
    word = {True: "yes", False: "no", None: "unclear"}[self.value]
    return f"{cat}: {word} — {self.source} ({self.detail})" if self.value is not True else f"{cat}: {self.source} ({self.detail})"


@dataclass
class Decision:
  verdicts: dict = field(default_factory=dict)

  def yes(self, cat):
    v = self.verdicts.get(cat)
    return bool(v and v.value is True)


@dataclass
class Film:
  tmdb: str
  items: dict = field(default_factory=dict)
  radarr: dict = field(default_factory=dict)
  facts: dict = field(default_factory=dict)
  tags: set = field(default_factory=set)
  direct: set = field(default_factory=set)
  nested: dict = field(default_factory=dict)

  @property
  def label(self):
    return f"{self.facts.get('title')} ({self.facts.get('year')})"


def build_facts(film):
  rec = next(iter(film.radarr.values()), {})
  item = film.items.get("uhd") or film.items.get("hd") or {}
  studios = [rec["studio"]] if rec.get("studio") else []
  studios += [s["Name"] for s in item.get("Studios", []) if s.get("Name") not in studios]
  runtime = rec.get("runtime") or round((item.get("RunTimeTicks") or 0) / 600_000_000) or None
  keywords = list(rec.get("keywords") or [])
  keywords += [t for t in item.get("Tags", []) if t not in keywords]
  coll = (rec.get("collection") or {}).get("tmdbId") or (item.get("ProviderIds") or {}).get("TmdbCollection")
  return {
    "title": rec.get("title") or item.get("Name"),
    "year": rec.get("year") or item.get("ProductionYear"),
    "certification": (rec.get("certification") or item.get("OfficialRating") or "").upper(),
    "genres": rec.get("genres") or item.get("Genres") or [],
    "studios": studios,
    "runtime": runtime,
    "keywords": [k.lower() for k in keywords],
    "overview": (rec.get("overview") or item.get("Overview") or "")[:300],
    "franchise_tmdb": str(coll) if coll else None,
  }


def norm_sort(s):
  return re.sub(r"\d+", lambda m: m.group().zfill(10), s.lower())


def matched(values, wanted):
  low = {w.lower() for w in wanted}
  return [v for v in values if v.lower() in low]


class Model:
  def __init__(self, enabled):
    self.url = os.environ.get("OLLAMA_URL", "http://ollama.network.svc.cluster.local:11434").rstrip("/")
    self.name = os.environ["OLLAMA_MODEL"]
    self.enabled = enabled
    self.calls = self.hits = self.failures = 0
    self.examples = {}
    self.status = "disabled (--no-model)"
    try:
      with open(CACHE_PATH) as f:
        self.cache = json.load(f)
    except (OSError, ValueError):
      self.cache = {}
    if enabled:
      try:
        names = [m["name"] for m in Http(self.url, {}).get("/api/tags").get("models", [])]
        if self.name in names:
          self.status = f"{self.name} available"
        else:
          self.enabled = False
          self.status = f"{self.name} not found on Ollama (has: {', '.join(names) or 'none'})"
      except Exception as e:
        self.enabled = False
        self.status = f"unreachable: {e}"
    log(f"model: {self.status}; {len(self.cache)} cached answers")

  def ask(self, f, cat, question):
    facts = {
      "title": f["title"], "year": f["year"], "rating": f["certification"] or "unrated",
      "genres": f["genres"][:5], "studio": (f["studios"] or [""])[0],
      "runtime_minutes": f["runtime"], "keywords": f["keywords"][:10], "overview": f["overview"],
    }
    prompt = json.dumps(facts, ensure_ascii=False) + "\n\nQuestion: " + question + "\nReply with exactly one word: yes or no."
    system = SYSTEM_PROMPT
    if self.examples.get(cat):
      system += "\n\nThe library owner has already answered this question for these movies. Judge other movies the same way:\n" + "\n".join(self.examples[cat])
    key = f"{cat}:{hashlib.sha256((self.name + system + prompt).encode()).hexdigest()[:16]}"
    if key in self.cache:
      self.hits += 1
      return self.cache[key]
    if not self.enabled:
      return None
    body = {
      "model": self.name, "stream": False, "think": False,
      "options": {"temperature": 0, "num_predict": 5},
      "messages": [{"role": "system", "content": system}, {"role": "user", "content": prompt}],
    }
    self.calls += 1
    try:
      res = Http(self.url, {}).request("POST", "/api/chat", body=body, timeout=120)
      word = re.sub(r"[^a-z]", "", (res["message"]["content"] or "").strip().split()[0].lower())
      if word not in ("yes", "no"):
        raise ValueError(f"unexpected answer {res['message']['content']!r}")
      answer = word == "yes"
    except Exception as e:
      self.failures += 1
      log(f"model call failed for {f['title']} ({cat}): {e}")
      return None
    self.cache[key] = answer
    try:
      with open(CACHE_PATH, "w") as fh:
        json.dump(self.cache, fh)
    except OSError:
      pass
    return answer


def kids_rule(f, cfg):
  r = cfg["kids"]
  cert = f["certification"]
  if cert in r["no_certifications"]:
    return False, f"rated {cert}"
  hits = matched(f["genres"], r["genres"]) or [k for k in f["keywords"] if k in {x.lower() for x in r["keywords"]}]
  if not hits:
    return False, f"not {' / '.join(r['genres'] + r['keywords'])}"
  if cert in r["certifications"]:
    return True, f"{cert}, {hits[0]}"
  return None, f"{cert or 'unrated'}, {', '.join(f['genres'][:3]) or 'no genres'}"


def holiday_rule(f, rc):
  if f["certification"] in rc.get("no_certifications", []):
    return False, f"rated {f['certification']}"
  bad = matched(f["genres"], rc.get("no_genres", [])) or [k for k in f["keywords"] if k in {x.lower() for x in rc.get("no_keywords", [])}]
  if bad:
    return False, f"excluded: {bad[0]}"
  for strong, terms in ((True, rc.get("strong_keywords", [])), (None, rc["keywords"])):
    for k in f["keywords"]:
      for t in terms:
        if re.search(rf"\b{re.escape(t.lower())}\b", k):
          return strong, f"keyword '{k}'"
  for w in rc["title_words"]:
    if re.search(rf"\b{re.escape(w.lower())}\b", (f["title"] or "").lower()):
      return None, f"title word '{w}'"
  return False, "no keyword or title word"


def override_entries(cfg, cat, kind):
  for x in cfg.get("overrides", {}).get(cat, {}).get(kind, []):
    if isinstance(x, dict):
      yield str(x["tmdb"]), x.get("note", "")
    else:
      yield str(x), ""


def override_ids(cfg, cat, kind):
  return {t for t, _ in override_entries(cfg, cat, kind)}


def build_examples(state, cfg):
  examples = {}
  for cat in CATEGORIES:
    lines = []
    for kind, word in (("include", "yes"), ("exclude", "no")):
      for tmdb, note in override_entries(cfg, cat, kind):
        film = state.films.get(tmdb)
        if not film:
          continue
        f = film.facts
        lines.append(f"- {f['title']} ({f['year']}, {f['certification'] or 'unrated'}): {word}" + (f" — {note}" if note else ""))
    if lines:
      examples[cat] = lines
  return examples


def classify(film: Film, cfg, model: Model) -> Decision:
  f = film.facts
  d = Decision()
  marker = cfg["marker_tag"]
  coll_cat = {c["name"]: c["category"] for c in cfg["collections"]}
  direct_cats = {coll_cat[n] for n in film.direct}
  if "shorts" in direct_cats:
    direct_cats.add("kids")

  for cat in CATEGORIES:
    if film.tmdb in override_ids(cfg, cat, "include"):
      d.verdicts[cat] = Verdict(True, "override", "config include")
      continue
    if film.tmdb in override_ids(cfg, cat, "exclude"):
      d.verdicts[cat] = Verdict(False, "override", "config exclude")
      continue
    if marker in film.tags:
      d.verdicts[cat] = Verdict(cat in film.tags, "tag", "Radarr tag" if cat in film.tags else "no Radarr tag")
      continue

    if cat == "kids":
      rv, rd = kids_rule(f, cfg)
    elif cat == "shorts":
      kids = d.verdicts["kids"].value
      rt = f["runtime"]
      if kids is None:
        rv, rd = None, "kids unclear"
      elif not kids:
        rv, rd = False, "not kids"
      elif rt is None:
        rv, rd = None, "no runtime"
      else:
        rv = rt <= cfg["shorts_max_minutes"]
        rd = f"{rt} min"
    else:
      rv, rd = holiday_rule(f, cfg[cat])

    if cat in direct_cats:
      names = ", ".join(sorted(n for n in film.direct if coll_cat[n] == cat or (cat == "kids" and coll_cat[n] == "shorts")))
      flag = f"rule says no ({rd})" if rv is False else ""
      d.verdicts[cat] = Verdict(True, "member", f"in {names}", flag)
      continue
    nested = [(n, fr) for n, frs in film.nested.items() for fr in frs if coll_cat[n] == cat or (cat == "kids" and coll_cat[n] == "shorts")]
    if nested:
      where = f"{nested[0][1]} in {nested[0][0]}"
      if rv is False:
        d.verdicts[cat] = Verdict(False, "rule", rd, f"nested member via {where}, excluded")
      else:
        d.verdicts[cat] = Verdict(True, "nested", where)
      continue

    if rv is not None:
      d.verdicts[cat] = Verdict(rv, "rule", rd)
      continue
    if cat == "shorts":
      d.verdicts[cat] = Verdict(None, "unclassified", rd)
      continue
    answer = model.ask(f, cat, cfg["model_questions"][cat])
    if answer is None:
      d.verdicts[cat] = Verdict(None, "unclassified", f"{rd}; no model answer")
    else:
      d.verdicts[cat] = Verdict(answer, "model", rd)
  return d


class State:
  def __init__(self, cfg):
    self.cfg = cfg
    self.jf = Jellyfin()
    self.version = self.jf.get("/System/Info").get("Version")
    log(f"jellyfin {self.version}, reading as {self.jf.user_name}")
    self.radarr = {}
    for lib in cfg["libraries"].values():
      if lib["radarr"] not in self.radarr:
        self.radarr[lib["radarr"]] = Radarr(lib["radarr"])
        log(f"{lib['radarr']}: {len(self.radarr[lib['radarr']].movies)} movies")

    self.films = {}
    self.item_film = {}
    self.ignored = []
    folders = {f["Name"]: f["ItemId"] for f in self.jf.get("/Library/VirtualFolders")}
    movies = []
    for lib in cfg["libraries"].values():
      if lib["name"] not in folders:
        raise SystemExit(f"Jellyfin library {lib['name']!r} not found")
      movies += self.jf.items(ParentId=folders[lib["name"]], IncludeItemTypes="Movie", Recursive="true",
                              Fields="Path,ProviderIds,Tags,Genres,Studios,OfficialRating,Overview")
    for m in movies:
      lib = self.library_of(m)
      tmdb = (m.get("ProviderIds") or {}).get("Tmdb")
      if not lib or not tmdb:
        self.ignored.append(m)
        continue
      film = self.films.setdefault(tmdb, Film(tmdb))
      if lib in film.items:
        log(f"two {lib} items for tmdb {tmdb}; keeping {film.items[lib]['Id']}")
        continue
      film.items[lib] = m
      self.item_film[m["Id"]] = film
    for film in self.films.values():
      for lib in film.items:
        rec = self.radarr[cfg["libraries"][lib]["radarr"]].movies.get(film.tmdb)
        if rec:
          film.radarr[cfg["libraries"][lib]["radarr"]] = rec
      for name, r in self.radarr.items():
        if name not in film.radarr and film.tmdb in r.movies:
          film.radarr[name] = r.movies[film.tmdb]
      film.tags = set().union(*(r["_tags"] for r in film.radarr.values())) if film.radarr else set()
      film.facts = build_facts(film)
    log(f"{len(self.films)} films from {len(movies)} Jellyfin movies ({len(self.ignored)} ignored)")

    self.boxsets = {b["Id"]: b for b in self.jf.items(IncludeItemTypes="BoxSet", Recursive="true", Fields="SortName,ProviderIds,Path")}
    self.children = {}
    for bid in self.boxsets:
      self.children[bid] = self.jf.items(ParentId=bid, Fields="Path,ProviderIds")
    log(f"{len(self.boxsets)} collections read")

    self.managed = {}
    self.renames = []
    for mc in cfg["collections"]:
      want = norm_sort(mc["sort_title"])
      hits = [b for b in self.boxsets.values() if b["Name"] == mc["name"] and b.get("SortName") == want]
      if not hits and mc.get("adopt_name"):
        prefix = norm_sort(mc["adopt_sort_prefix"])
        hits = [b for b in self.boxsets.values() if b["Name"] == mc["adopt_name"] and (b.get("SortName") or "").startswith(prefix)]
        if hits:
          self.renames.append((hits[0], mc))
      self.managed[mc["name"]] = hits[0] if hits else None
    managed_ids = {b["Id"] for b in self.managed.values() if b}
    self.franchises = {bid: b for bid, b in self.boxsets.items() if bid not in managed_ids}

    self.film_franchises = {}
    for bid in self.franchises:
      for c in self.children[bid]:
        film = self.item_film.get(c["Id"])
        if film:
          self.film_franchises.setdefault(film.tmdb, set()).add(bid)
    by_tmdb = {}
    for bid, b in self.franchises.items():
      t = (b.get("ProviderIds") or {}).get("Tmdb")
      if t:
        by_tmdb.setdefault(t, set()).add(bid)
    for film in self.films.values():
      if film.facts["franchise_tmdb"] in by_tmdb:
        self.film_franchises.setdefault(film.tmdb, set()).update(by_tmdb[film.facts["franchise_tmdb"]])

    for name, b in self.managed.items():
      if not b:
        continue
      for c in self.children[b["Id"]]:
        film = self.item_film.get(c["Id"])
        if film:
          film.direct.add(name)
        elif c["Id"] in self.franchises:
          for fc in self.children[c["Id"]]:
            ff = self.item_film.get(fc["Id"])
            if ff:
              ff.nested.setdefault(name, set()).add(c["Name"])

  def library_of(self, item):
    path = item.get("Path") or ""
    for key, lib in self.cfg["libraries"].items():
      if path.startswith(lib["path_prefix"]):
        return key
    return None

  def franchise_of(self, film):
    cands = self.film_franchises.get(film.tmdb)
    if not cands:
      return None
    def movie_count(bid):
      return sum(1 for c in self.children[bid] if c.get("Type") == "Movie")
    return sorted(cands, key=lambda bid: (
      not (self.franchises[bid].get("ProviderIds") or {}).get("Tmdb"),
      -movie_count(bid),
      self.franchises[bid]["Name"].lower(),
    ))[0]

  def pick_copy(self, film, copy):
    if copy == "preferred":
      first = self.cfg["single_copy_prefers"]
      other = "hd" if first == "uhd" else "uhd"
      return film.items.get(first) or film.items.get(other)
    return film.items.get(copy)


def target_membership(state: State, decisions) -> dict:
  targets = {}
  for mc in state.cfg["collections"]:
    films, franchises = {}, {}
    for film in state.films.values():
      d = decisions[film.tmdb]
      if not d.yes(mc["category"]) or any(d.yes(x) for x in mc["exclude"]):
        continue
      item = state.pick_copy(film, mc["copy"])
      if not item:
        continue
      films[item["Id"]] = (film, item)
      fr = state.franchise_of(film)
      if fr:
        franchises.setdefault(fr, []).append(film)
    targets[mc["name"]] = {"films": films, "franchises": franchises}
  return targets


def lib_label(state, item):
  lib = state.library_of(item)
  return state.cfg["libraries"][lib]["label"] if lib else "?"


def why_not(state, mc, decisions, item):
  film = state.item_film.get(item["Id"])
  if not film:
    return "outside the managed libraries" if item.get("Type") == "Movie" else f"{item.get('Type')}, not a franchise"
  d = decisions[film.tmdb]
  v = d.verdicts[mc["category"]]
  if v.value is not True:
    return v.text(mc["category"])
  for x in mc["exclude"]:
    if d.yes(x):
      return d.verdicts[x].text(x)
  want = state.pick_copy(film, mc["copy"])
  return f"wrong copy; target is the {lib_label(state, want)} copy" if want else "no copy in the target library"


def line(mark, text, reason, width=58):
  return f"    {mark} {text.ljust(width)} {reason}".rstrip()


def report(state: State, decisions, model: Model) -> str:
  cfg = state.cfg
  targets = target_membership(state, decisions)
  out = ["# Jellyfin collections — dry-run report", ""]
  both = sum(1 for f in state.films.values() if len(f.items) == 2)
  out += [
    f"- Generated {time.strftime('%Y-%m-%d %H:%M %Z')}; Jellyfin {state.version}, read as `{state.jf.user_name}`"
    + ("" if state.jf.all_folders else " (this admin does not have access to all libraries)"),
    f"- Films: {len(state.films)} ({both} with both HD and UHD copies); Jellyfin movies skipped (no TMDB ID or unexpected path): {len(state.ignored)}",
    f"- Model: {model.status}; {model.calls} calls, {model.hits} cached, {model.failures} failed",
    "",
    "Legend: `+` would be added, `-` would be removed, `=` already there. Reasons: `member` = already in that collection by hand, "
    "`nested` = in a franchise nested in that collection, `rule` = config rules, `model` = Ollama answered, `override` = config.json, `tag` = Radarr tag.",
    "",
  ]

  out += ["## Summary", "", "| Collection | Films | + | - | Franchises | + | - |", "|---|---|---|---|---|---|---|"]
  sections = []
  for mc in cfg["collections"]:
    name = mc["name"]
    box = state.managed[name]
    t = targets[name]
    current = state.children[box["Id"]] if box else []
    cur_films = {c["Id"]: c for c in current if c["Id"] not in state.franchises}
    cur_fr = {c["Id"]: c for c in current if c["Id"] in state.franchises}
    f_add = [i for i in t["films"] if i not in cur_films]
    f_del = [i for i in cur_films if i not in t["films"]]
    fr_add = [i for i in t["franchises"] if i not in cur_fr]
    fr_del = [i for i in cur_fr if i not in t["franchises"]]
    out.append(f"| {name} | {len(t['films'])} | {len(f_add)} | {len(f_del)} | {len(t['franchises'])} | {len(fr_add)} | {len(fr_del)} |")

    s = [f"## {name} — films row: {len(t['films'])} (+{len(f_add)}, -{len(f_del)}); collections row: {len(t['franchises'])} (+{len(fr_add)}, -{len(fr_del)})", ""]
    if not box:
      s += ["_Collection not found in Jellyfin; it would be created._", ""]
    elif any(r[1] is mc for r in state.renames):
      s += [f"_Existing collection \"{box['Name']}\" would be renamed to \"{name}\" (sort title `{mc['sort_title']}`)._", ""]
    s.append("films")
    rows = []
    for iid, (film, item) in t["films"].items():
      mark = "=" if iid in cur_films else "+"
      v = decisions[film.tmdb].verdicts[mc["category"]]
      rows.append((film.facts["title"] or "", line(mark, f"{film.label} [{lib_label(state, item)}]", v.text(mc["category"]))))
    for iid in f_del:
      c = cur_films[iid]
      film = state.item_film.get(iid)
      label = f"{film.label} [{lib_label(state, c)}]" if film else f"{c.get('Name')} [{c.get('Type')}]"
      rows.append((label, line("-", label, why_not(state, mc, decisions, c))))
    s += [r for _, r in sorted(rows, key=lambda x: x[0].lower())]
    s.append("collections")
    frows = []
    for bid, via in t["franchises"].items():
      mark = "=" if bid in cur_fr else "+"
      b = state.franchises[bid]
      block = [line(mark, b["Name"], "via " + ", ".join(sorted(f.label for f in via)))]
      via_ids = {f.tmdb for f in via}
      shown = set()
      for c in sorted(state.children[bid], key=lambda c: c.get("ProductionYear") or 0):
        film = state.item_film.get(c["Id"])
        if not film or film.tmdb in via_ids or film.tmdb in shown:
          continue
        shown.add(film.tmdb)
        d = decisions[film.tmdb]
        v = d.verdicts[mc["category"]]
        excl = [x for x in mc["exclude"] if d.yes(x)]
        if v.value is True and not excl:
          continue
        why = f"is {excl[0]}" if v.value is True else v.text(mc["category"])
        block.append(line("!", f"  {film.label}", f"not on its own: {why}", 56))
      frows.append((b["Name"].lower(), block))
    for bid in fr_del:
      frows.append((state.franchises[bid]["Name"].lower(), [line("-", state.franchises[bid]["Name"], "no qualifying film any more")]))
    for _, block in sorted(frows):
      s += block
    sections.append("\n".join(s))
  out.append("")
  out += [s + "\n" for s in sections]

  flagged = [(f, cat, v) for f in state.films.values() for cat, v in decisions[f.tmdb].verdicts.items() if v.flag]
  out += ["## Conflicts to review", "", "Hand-made membership disagrees with the rules. Membership wins unless noted.", ""]
  out += [f"- {f.label} — {cat}: {v.flag}; decided {v.text(cat)}" for f, cat, v in sorted(flagged, key=lambda x: x[0].label)] or ["- none"]
  out.append("")

  modeled = [(f, cat, v) for f in state.films.values() for cat, v in decisions[f.tmdb].verdicts.items() if v.source == "model"]
  out += ["## Model decisions", "", "The rules could not decide these; Ollama answered. Override any in config.json.", ""]
  for cat in CATEGORIES:
    rows = sorted((f.label, f.tmdb, v) for f, c, v in modeled if c == cat)
    if rows:
      out.append(f"### {cat}: {sum(1 for r in rows if r[2].value)} yes, {sum(1 for r in rows if not r[2].value)} no")
      out += [f"- {'yes' if v.value else 'no '} {label} (tmdb {tmdb}) — {v.detail}" for label, tmdb, v in rows]
      out.append("")
  if not modeled:
    out += ["- none", ""]

  unclassified = sorted((f.label, f.tmdb, cat, v) for f in state.films.values() for cat, v in decisions[f.tmdb].verdicts.items() if v.value is None)
  out += ["## Unclassified", "", "No answer yet; these stay out of every collection until a later run decides them.", ""]
  out += [f"- {label} (tmdb {tmdb}) — {cat}: {v.detail}" for label, tmdb, cat, v in unclassified] or ["- none"]
  out.append("")

  managed_ids = {b["Id"] for b in state.managed.values() if b}
  empty = [b for bid, b in state.boxsets.items() if not state.children[bid]]
  will_empty = [n for n in targets if state.managed[n] and not targets[n]["films"] and not targets[n]["franchises"]]
  tasks = {t.get("Key"): t.get("State") for t in state.jf.get("/ScheduledTasks")}
  running = [k for k in cfg["scan_task_keys"] if tasks.get(k) == "Running"]
  out += ["## Empty collections", ""]
  if len(empty) > cfg["max_deletions_per_run"]:
    out.append(f"_Safety brake: {len(empty)} empty collections exceed max_deletions_per_run={cfg['max_deletions_per_run']}; none would be deleted._")
  if running:
    out.append(f"_Scan running ({', '.join(running)}); deletions would be skipped this run._")
  out += [f"- would delete: {b['Name']}{' (managed)' if b['Id'] in managed_ids else ''}" for b in sorted(empty, key=lambda b: b["Name"])] or ["- none empty now"]
  out += [f"- would become empty after membership changes: {n}" for n in will_empty]
  out.append("")

  out += ["## Posters", ""]
  for mc in cfg["collections"]:
    b = state.managed[mc["name"]]
    has = bool(b and (b.get("ImageTags") or {}).get("Primary"))
    if mc.get("poster"):
      out.append(f"- {mc['name']}: {'has a poster; left alone' if has else 'no poster; would upload ' + mc['poster']}")
    else:
      out.append(f"- {mc['name']}: {'has a poster' if has else 'no poster, none configured'}; service leaves it alone")
  out.append("")

  marker = cfg["marker_tag"]
  writes = sum(1 for f in state.films.values() for rec in f.radarr.values() if marker not in rec["_tags"])
  missing = [f.label for f in state.films.values() if not f.radarr]
  out += ["## Radarr", "", f"- Seeding would write tags to {writes} Radarr movie records.",
          f"- Films with no Radarr record (decisions cannot be stored): {len(missing)}" + (": " + ", ".join(sorted(missing)[:20]) if missing else ""), ""]
  return "\n".join(out)


def plan_tag_fixes(state):
  fixes = {}
  for film in sorted(state.films.values(), key=lambda f: f.label.lower()):
    for name, rec in film.radarr.items():
      if state.cfg["marker_tag"] not in rec["_tags"]:
        continue
      for cat in CATEGORIES:
        if film.tmdb in override_ids(state.cfg, cat, "include") and cat not in rec["_tags"]:
          fixes.setdefault(name, {}).setdefault((cat, "add"), []).append((film, rec))
        elif film.tmdb in override_ids(state.cfg, cat, "exclude") and cat in rec["_tags"]:
          fixes.setdefault(name, {}).setdefault((cat, "remove"), []).append((film, rec))
  return fixes


def plan_tag_writes(state, decisions):
  marker = state.cfg["marker_tag"]
  writes, skipped = {}, []
  for film in sorted(state.films.values(), key=lambda f: f.label.lower()):
    d = decisions[film.tmdb]
    unclear = [c for c, v in d.verdicts.items() if v.value is None]
    if unclear:
      skipped.append((film, unclear))
      continue
    cats = tuple(c for c in CATEGORIES if d.yes(c))
    for name, rec in film.radarr.items():
      if marker in rec["_tags"]:
        continue
      writes.setdefault(name, {}).setdefault(cats, []).append((film, rec))
  return writes, skipped


def seed(state, decisions, dry_run) -> str:
  marker = state.cfg["marker_tag"]
  writes, skipped = plan_tag_writes(state, decisions)
  fixes = plan_tag_fixes(state)
  out = [f"# Radarr tag seeding — {'preview (DRY_RUN)' if dry_run else 'applied'}", ""]
  for name in sorted(writes):
    groups = writes[name]
    total = sum(len(v) for v in groups.values())
    out += [f"## {name}: {total} movie records", ""]
    out += [f"- `{', '.join(cats + (marker,))}`: {len(films)}" for cats, films in sorted(groups.items(), key=lambda x: (-len(x[0]), x[0]))]
    out.append("")
    for cats, films in sorted(groups.items()):
      if not cats:
        continue
      out.append(f"### {name}: {', '.join(cats)}")
      for film, _ in films:
        why = "; ".join(f"{c}: {decisions[film.tmdb].verdicts[c].source}" for c in cats)
        out.append(f"- {film.label} — {why}")
      out.append("")
  if not writes:
    out += ["Nothing to write: every movie record already has the marker tag.", ""]
  out += ["## Tag corrections from config overrides", ""]
  for name in sorted(fixes):
    for (cat, action), films in sorted(fixes[name].items()):
      out += [f"- {name}: {action} `{cat}` — {f.label}" for f, _ in films]
  if not fixes:
    out.append("- none")
  out.append("")
  out += ["## Skipped (unclassified, retried next run)", ""]
  out += [f"- {f.label} — {', '.join(u)}" for f, u in skipped] or ["- none"]
  out.append("")
  if dry_run:
    return "\n".join(out)

  for name in sorted(set(writes) | set(fixes)):
    groups = writes.get(name, {})
    r = state.radarr[name]
    ids = {t["label"]: t["id"] for t in r.get("/api/v3/tag")}
    for label in list(CATEGORIES) + [marker]:
      if label not in ids:
        ids[label] = r.request("POST", "/api/v3/tag", body={"label": label})["id"]
        log(f"{name}: created tag {label}")
    for cats, films in groups.items():
      tag_ids = [ids[c] for c in cats + (marker,)]
      movie_ids = [rec["id"] for _, rec in films]
      for i in range(0, len(movie_ids), 100):
        batch = movie_ids[i:i + 100]
        r.request("PUT", "/api/v3/movie/editor", body={"movieIds": batch, "tags": tag_ids, "applyTags": "add"})
        log(f"{name}: tagged {len(batch)} movies with {', '.join(cats + (marker,))}")
    for (cat, action), films in fixes.get(name, {}).items():
      movie_ids = [rec["id"] for _, rec in films]
      r.request("PUT", "/api/v3/movie/editor", body={"movieIds": movie_ids, "tags": [ids[cat]], "applyTags": action})
      log(f"{name}: {action} {cat} on {len(movie_ids)} movies to match config overrides")
  return "\n".join(out)


def update_item(jf, iid, changes):
  dto = jf.get(f"/Items/{iid}", userId=jf.user_id)
  dto.update(changes)
  jf.request("POST", f"/Items/{iid}", body=dto)


def edit_members(jf, method, cid, ids):
  for i in range(0, len(ids), 50):
    jf.request(method, f"/Collections/{cid}/Items", params={"Ids": ",".join(ids[i:i + 50])})


def reconcile(state, decisions, dry_run) -> str:
  cfg = state.cfg
  jf = state.jf
  out = [f"# Jellyfin collections — reconcile {'preview (DRY_RUN)' if dry_run else 'applied'}", "",
         f"- {time.strftime('%Y-%m-%d %H:%M %Z')}; Jellyfin {state.version}", ""]
  total = 0

  writes, skipped = plan_tag_writes(state, decisions)
  fixes = plan_tag_fixes(state)
  out += ["## Radarr tags", ""]
  for name in sorted(writes):
    for cats, films in sorted(writes[name].items()):
      out += [f"- {name}: tag {film.label} with `{', '.join(cats + (cfg['marker_tag'],))}`" for film, _ in films]
  for name in sorted(fixes):
    for (cat, action), films in sorted(fixes[name].items()):
      out += [f"- {name}: {action} `{cat}` on {film.label} (config override)" for film, _ in films]
  out += [f"- not tagged yet (unclassified): {film.label} — {', '.join(u)}" for film, u in skipped]
  n_tags = sum(len(v) for g in writes.values() for v in g.values()) + sum(len(v) for g in fixes.values() for v in g.values())
  if not n_tags and not skipped:
    out.append("- no changes")
  out.append("")
  total += n_tags
  if n_tags and not dry_run:
    seed(state, decisions, False)

  targets = target_membership(state, decisions)
  out += ["## Collections", ""]
  for mc in cfg["collections"]:
    name = mc["name"]
    box = state.managed[name]
    t = targets[name]
    want = list(t["films"]) + list(t["franchises"])
    cur = {c["Id"]: c for c in state.children[box["Id"]]} if box else {}
    add = [i for i in want if i not in cur]
    remove, kept = [], []
    for iid, c in cur.items():
      if iid in t["films"] or iid in t["franchises"]:
        continue
      film = state.item_film.get(iid)
      if film and decisions[film.tmdb].verdicts[mc["category"]].value is None:
        kept.append(iid)
        continue
      remove.append(iid)
    rename = next((b for b, m in state.renames if m is mc), None)
    changes = len(add) + len(remove) + (1 if rename else 0) + (1 if not box and want else 0)
    total += changes
    out.append(f"### {name}: +{len(add)} -{len(remove)}" + ("" if changes else " (no changes)"))
    if rename:
      out.append(f"- rename \"{rename['Name']}\" to \"{name}\" (sort title `{mc['sort_title']}`)")
    if not box:
      out.append(f"- create collection (sort title `{mc['sort_title']}`, display order {mc['display_order']})" if want else "- missing in Jellyfin; nothing qualifies, so not created")
    rows = []
    for iid in add:
      if iid in t["franchises"]:
        rows.append(f"- + {state.franchises[iid]['Name']} (collection) — via {', '.join(sorted(f.label for f in t['franchises'][iid]))}")
      else:
        film, item = t["films"][iid]
        rows.append(f"- + {film.label} [{lib_label(state, item)}] — {decisions[film.tmdb].verdicts[mc['category']].text(mc['category'])}")
    for iid in remove:
      c = cur[iid]
      if iid in state.franchises:
        rows.append(f"- - {c['Name']} (collection) — no qualifying film any more")
      else:
        film = state.item_film.get(iid)
        label = f"{film.label} [{lib_label(state, c)}]" if film else f"{c.get('Name')} [{c.get('Type')}]"
        rows.append(f"- - {label} — {why_not(state, mc, decisions, c)}")
    for iid in kept:
      rows.append(f"- = {state.item_film[iid].label} kept for now — {mc['category']} unclassified")
    out += sorted(rows, key=lambda r: r[4:].lower())
    out.append("")
    if dry_run:
      continue
    if rename:
      update_item(jf, rename["Id"], {"Name": name, "ForcedSortName": mc["sort_title"]})
      log(f"renamed {rename['Name']!r} to {name!r}")
    if not box and want:
      res = jf.request("POST", "/Collections", params={"Name": name, "Ids": ",".join(want[:50])})
      box = {"Id": res["Id"], "Name": name}
      update_item(jf, box["Id"], {"ForcedSortName": mc["sort_title"], "DisplayOrder": mc["display_order"]})
      add = want[50:]
      log(f"created {name!r}")
    if add:
      edit_members(jf, "POST", box["Id"], add)
      log(f"{name}: added {len(add)}")
    if remove:
      edit_members(jf, "DELETE", box["Id"], remove)
      log(f"{name}: removed {len(remove)}")

  wanted = {state.managed[n]["Id"] for n, t in targets.items() if state.managed[n] and (t["films"] or t["franchises"])}
  empty = sorted((b for bid, b in state.boxsets.items() if not state.children[bid] and bid not in wanted), key=lambda b: b["Name"])
  tasks = {x.get("Key"): x.get("State") for x in jf.get("/ScheduledTasks")}
  running = [k for k in cfg["scan_task_keys"] if tasks.get(k) == "Running"]
  out += ["## Empty collections", ""]
  if not empty:
    out.append("- none")
  elif len(empty) > cfg["max_deletions_per_run"]:
    out.append(f"- safety brake: {len(empty)} empty collections exceed max_deletions_per_run={cfg['max_deletions_per_run']}; none deleted: " + ", ".join(b["Name"] for b in empty))
    empty = []
  elif running:
    out.append(f"- library scan running ({', '.join(running)}); skipped: " + ", ".join(b["Name"] for b in empty))
    empty = []
  out += [f"- delete {b['Name']}" for b in empty]
  out.append("")
  total += len(empty)
  if not dry_run:
    for b in empty:
      jf.request("DELETE", f"/Items/{b['Id']}")
      log(f"deleted empty collection {b['Name']!r}")

  out.insert(3, f"- {total} change{'s' if total != 1 else ''}{' planned' if dry_run else ' applied'}")
  return "\n".join(out)


def classify_all(state, model):
  decisions = {}
  todo = sorted(state.films.values(), key=lambda f: f.facts["title"] or "")
  for i, film in enumerate(todo, 1):
    decisions[film.tmdb] = classify(film, state.cfg, model)
    if i % 200 == 0:
      log(f"classified {i}/{len(todo)} (model calls so far: {model.calls})")
  return decisions


RUN_LOCK = threading.Lock()


def run(command, use_model=True) -> str:
  with RUN_LOCK:
    cfg = load_config()
    state = State(cfg)
    model = Model(enabled=use_model)
    model.examples = build_examples(state, cfg)
    log("model examples: " + ", ".join(f"{c}={len(v)}" for c, v in model.examples.items()))
    decisions = classify_all(state, model)
    if model.failures:
      log(f"{model.failures} model calls failed; those films stay unclassified until the next run")
    if command == "report":
      return report(state, decisions, model)
    dry_run = env_bool("DRY_RUN")
    if command == "seed":
      if not dry_run and model.failures:
        raise SystemExit(f"{model.failures} model calls failed; not seeding")
      return seed(state, decisions, dry_run)
    return reconcile(state, decisions, dry_run)


def next_run_at(hour):
  now = time.time()
  lt = time.localtime(now)
  at = time.mktime((lt.tm_year, lt.tm_mon, lt.tm_mday, hour, 0, 0, 0, 0, -1))
  if at <= now:
    at = time.mktime((lt.tm_year, lt.tm_mon, lt.tm_mday + 1, hour, 0, 0, 0, 0, -1))
  return at


def daily():
  hour = int(os.environ.get("RECONCILE_HOUR", "4"))
  while True:
    at = next_run_at(hour)
    log(f"next reconcile at {time.strftime('%Y-%m-%d %H:%M %Z', time.localtime(at))}")
    time.sleep(max(0, at - time.time()))
    try:
      print(run("reconcile"), flush=True)
    except BaseException as e:
      log(f"reconcile failed: {e!r}")


def serve():
  class Handler(http.server.BaseHTTPRequestHandler):
    def reply(self, code, body):
      data = json.dumps(body).encode()
      self.send_response(code)
      self.send_header("Content-Type", "application/json")
      self.send_header("Content-Length", str(len(data)))
      self.end_headers()
      self.wfile.write(data)

    def do_GET(self):
      if self.path == "/healthz":
        self.reply(200, {"ok": True, "dry_run": env_bool("DRY_RUN")})
      else:
        self.reply(404, {"error": "not found"})

    def do_POST(self):
      self.reply(501, {"error": "webhook and re-evaluate are not enabled yet"})

    def log_message(self, fmt, *args):
      if not self.path.startswith("/healthz"):
        log(fmt % args)

  signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
  load_config()
  server = http.server.ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), Handler)
  log(f"serving on :{server.server_port} (dry_run={env_bool('DRY_RUN')})")
  threading.Thread(target=server.serve_forever, daemon=True).start()
  threading.Thread(target=daily, daemon=True).start()
  while True:
    time.sleep(3600)


def main():
  p = argparse.ArgumentParser(description="Keep curated Jellyfin collections in sync with Radarr tags")
  p.add_argument("command", choices=["serve", "report", "seed", "reconcile"])
  p.add_argument("--no-model", action="store_true", help="skip Ollama calls; unclear films stay unclassified")
  args = p.parse_args()
  if args.command == "serve":
    serve()
  else:
    print(run(args.command, use_model=not args.no_model))


if __name__ == "__main__":
  main()
