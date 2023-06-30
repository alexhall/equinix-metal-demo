# Equinix Metal Demo

This repository contains a complete end-to-end implementation of a simple
containerized web application, deployed on Equinix Metal infrastructure provisioned
via Terraform.

The intent of this demo is to explore what a minimal migration path to Equinix Metal
might look like for the developer of an existing containerized application that is built
and deployed to the public cloud using industry-standard CI/CD and IaC tooling.

## Requirements

* Metal API Token
* Terraform
* Docker

## Provision

Equinix Metal infrastructure is provisioned via a Terraform project in the `/terraform`
directory. Terraform state is stored locally for now, and the plan is run manually as
a one-off operation with no support for collaboration between developers.

Provision the infrastructure as follows:

```bash
$ cd terraform
$ terraform init
$ METAL_AUTH_TOKEN=[auth_token] terraform apply
```

Applying the plan provisions the Metal infrastructure, and also produces the following
resources needed for deployment:

* Generated SSH private key, written to `~/.ssh/equinix-metal-terraform-rsa`.
* Metal server public IP address, written as the `server_public_ip` plan output.

## Build

The application is built as a Docker image (currently just some static HTML served
via Apache HTTPD) and published to the Github Packages container registry for this repo.

To build, locally, you'll need to authenticate using a Github Personal Access Token:

```bash
$ export CR_PAT=[github_personal_token]
$ echo $CR_PAT | docker login ghcr.io -u [username] --password-stdin
```

Then, build and publish:

```bash
$ ./build.sh
```

By default, the images is published with tags `latest` and the current Git SHA.
To specify and alternate tag to the Git SHA, set the `IMAGE_TAG` environment variable.

## Deploy

The application deployment process is done via a simple bash script that issues
commands via SSH to the Metal server to pull and run the container image from the
Github registry. Run it as follows:

```bash
$ EQX_METAL_SERVER_IP=[server_public_ip] \
    DEPLOY_SSH_PRIVATE_KEY=$(cat ~/.ssh/equinix-metal-terraform-rsa) \
    ./deploy.sh
```

By default, the image tagged with the current Git SHA is deployed. To deploy an
alternate image, set the `IMAGE_TAG` environment variable.

## Next Steps

In this section we discuss potential next steps to address real-world use cases
required in order to make this demo application more production-ready.

### Terraform State

To enable collaboration between developers as well as running the plan in a
CI/CD pipeline, we would need to switch from local state storage to a backend
that allows state to be accessed remotely. Options include:

* Terraform Cloud for a more managed experience
* Use one of the builtin backends for cloud provider object stores (
  `azurerm`, `gcs`, `s3`, etc.) - this is a natural migration path if we're already
  using one of those cloud providers.
* If we want Equinix-hosted state storage, consider running
  [MinIO on Metal](https://deploy.equinix.com/developers/guides/minio-terraform/) and
  using the `s3` backend.

### OIDC

Once we have the Terraform plan running in Github Actions, look at
[OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
avoid storing a long-lived API token in the project config.

### Compute Cluster

For running containerized applications with production workloads, we generally want
to register the Metal servers with a cluster manager of some sort and use that to
manage orchestration and deployments. Options include:

* [Amazon ECS Anywhere](https://github.com/equinix/terraform-equinix-metal-ecs-anywhere) - Natural migration path if we're migrating from AWS-hosted ECS.
* [Kubernetes](https://deploy.equinix.com/developers/guides/kubernetes-with-kubeadm/) - Default open-source container orchestration framework.

### Network Security

To reduce surface area for attack, we don't want to have our production workloads
running on servers that are directly connected to the public internet, which is the
default server configuration. Considerations include:

* Create the servers without public IPs on a VLAN behind a firewall
* Set up a bastion host for SSH tunneling if connectivity from public internet is needed
* Use hosted runners so CI/CD workflows don't need public internet for infra connections

### SSH Key Management

For a production system, we'd expect better management of our SSH private keys.

* Minimize the number of people with access to production keys by storing them in
  a central vault with tightly controlled access and injected into CI/CD pipelines
  as needed rather than configuring as project-level environment variables.
* Consider setting up a certificate authority that can issue temporary access keys
  with expiration dates that can be revoked or rotated as needed.
* Larger organizations might consider commercial solutions e.g.
  [Teleport](https://goteleport.com/features/sso-for-ssh/) or
  [Border0](https://www.border0.com/) that support SSO integration for SSH.

### HTTP Endpoint

Right now the app is served over unsecure HTTP using the public IP address.

* Set up DNS for the public HTTP endpoint.
* Set up HTTPS for secure access.
* Put application workers behind an HTTP load-balancer that terminates HTTPS.

### Application Functionality

Just running a container on a Metal server isn't a very compelling use-case.
Come up with a representative use-case that might motivate a migration to Metal
and update the application as necessary to reflect that.
