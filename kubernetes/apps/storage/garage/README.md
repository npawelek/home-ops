# Garage

Self-hosted S3-compatible object storage backed by NFS on racknas.

## Initial Setup

Garage's cluster layout (node roles, zones, capacity) is runtime state and must be applied once after the first deployment. It persists in the LMDB database on the NFS mount and survives pod restarts.

Get the node ID:

```sh
kubectl exec -n storage garage-0 -- /garage status
```

Assign the node a zone and capacity, then apply the layout:

```sh
kubectl exec -n storage garage-0 -- /garage layout assign -z racknas -c 1T <node-id>
kubectl exec -n storage garage-0 -- /garage layout apply --version 1
```

This only needs to be done once. If `/meta` is ever wiped, repeat these steps.

## Creating Buckets

```sh
kubectl exec -n storage garage-0 -- /garage bucket create <bucket-name>
```

## Access Keys & Bucket Permissions

Garage requires access keys to be created and explicitly granted permissions per bucket. One key can cover multiple buckets.

Create a key:

```sh
kubectl exec -n storage garage-0 -- /garage key create <key-name>
```

Grant the key access to a bucket (repeat for each bucket):

```sh
kubectl exec -n storage garage-0 -- /garage bucket allow --read --write --owner <bucket-name> --key <key-name>
```

The output of `key create` provides the access key ID and secret to use as S3 credentials in your app.
