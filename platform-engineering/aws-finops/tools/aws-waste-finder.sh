#!/usr/bin/env bash
# aws-waste-finder.sh — READ-ONLY idle / orphaned-resource inventory (one Region).
#
# Surfaces removable AWS waste: unattached EBS volumes, unassociated Elastic IPs
# (billed while idle), stopped EC2 instances (compute stops but EBS + EIP still bill),
# aged EBS snapshots, and load balancers to review for empty target groups. Only runs
# `aws ec2 describe-*` / `aws elbv2 describe-*` (reads); it never detaches, releases,
# resizes, or removes anything. Needs EC2/ELB read access (a read-only / describe policy).
# EC2 is regional — set AWS_REGION (or --region via AWS_DEFAULT_REGION) per Region.
#
# Review this script before running. This is a CANDIDATE list, not an approval to
# remove — a "dead" volume or snapshot may be a DR / forensic / staging asset. Confirm
# each with its owner, then remove via a separate, human-approved change (IaC PR).
#
# Usage:
#   AWS_REGION=us-east-1 bash aws-waste-finder.sh
#   AWS_REGION=eu-west-1 SNAP_OWNER=self bash aws-waste-finder.sh
set -euo pipefail

command -v aws >/dev/null 2>&1 || { echo "aws CLI not found on PATH" >&2; exit 2; }
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
SNAP_OWNER="${SNAP_OWNER:-self}"
echo "== Region: ${REGION}  ·  read-only waste inventory =="
echo

echo "== Unattached EBS volumes (status=available — pure storage waste) =="
aws ec2 describe-volumes --region "${REGION}" \
  --filters Name=status,Values=available \
  --query "Volumes[].[VolumeId, Size, VolumeType, AvailabilityZone, CreateTime]" \
  --output table 2>/dev/null || echo "  (none / query failed)"
echo

echo "== Unassociated Elastic IPs (billed while not attached to a running instance) =="
aws ec2 describe-addresses --region "${REGION}" \
  --query "Addresses[?AssociationId==null].[PublicIp, AllocationId, Domain]" \
  --output table 2>/dev/null || echo "  (none / query failed)"
echo

echo "== Stopped EC2 instances (compute stops, but attached EBS + EIP keep billing) =="
aws ec2 describe-instances --region "${REGION}" \
  --filters Name=instance-state-name,Values=stopped \
  --query "Reservations[].Instances[].[InstanceId, InstanceType, LaunchTime]" \
  --output table 2>/dev/null || echo "  (none / query failed)"
echo

echo "== Self-owned EBS snapshots (aged snapshots accumulate cost) =="
aws ec2 describe-snapshots --region "${REGION}" --owner-ids "${SNAP_OWNER}" \
  --query "Snapshots[].[SnapshotId, VolumeId, VolumeSize, StartTime]" \
  --output table 2>/dev/null | head -40 || echo "  (none / query failed)"
echo

echo "== Load balancers (review each for empty target groups = paying for nothing) =="
aws elbv2 describe-load-balancers --region "${REGION}" \
  --query "LoadBalancers[].[LoadBalancerName, Type, State.Code]" \
  --output table 2>/dev/null || echo "  (none / query failed — classic ELBs use 'aws elb')"
echo

echo "Goal: a defensible candidate list of idle/orphaned resources. The biggest AWS"
echo "waste bucket is usually over-provisioned compute (Compute Optimizer / Cost"
echo "Optimization Hub), not orphans. Confirm each candidate with its owner, then remove"
echo "via a gated, human-approved change. This script only reads — nothing is removed here."
