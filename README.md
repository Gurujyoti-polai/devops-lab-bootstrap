# devops-lab-bootstrap

Reusable AWS lab infrastructure — spins up a full VPC + EC2 environment with one command, tears it down with one command.

## Status
- [x] Phase -1 Session 1: Tools installed, S3 backend created
- [ ] Phase -1 Session 2: OpenTofu module + Ansible inventory
- [ ] Phase -1 Session 3: Makefile + GitHub Actions
- [ ] Phase -1 Session 4: End-to-end test

## Cost warning
NAT Gateway bills ~₹3.50/hr from the moment it exists.
Always run `make down` at the end of every session.
