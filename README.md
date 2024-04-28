# Coworking Space Service Extension
The Coworking Space Service is a set of APIs that enables users to request one-time tokens and administrators to authorize access to a coworking space. This service follows a microservice pattern and the APIs are split into distinct services that can be deployed and managed independently of one another.

For this project, you are a DevOps engineer who will be collaborating with a team that is building an API for business analysts. The API provides business analysts basic analytics data on user activity in the service. The application they provide you functions as expected locally and you are expected to help build a pipeline to deploy it in Kubernetes.

## Getting Started

### Dependencies
#### Local Environment
1. Python Environment - run Python 3.6+ applications and install Python dependencies via `pip`
2. Docker CLI - build and run Docker images locally
3. `kubectl` - run commands against a Kubernetes cluster
4. `helm` - apply Helm Charts to a Kubernetes cluster

#### Remote Resources
1. AWS CodeBuild - build Docker images remotely
2. AWS ECR - host Docker images
3. Kubernetes Environment with AWS EKS - run applications in k8s
4. AWS CloudWatch - monitor activity and logs in EKS
5. GitHub - pull and clone code

### Setup
#### 1. Create and configure you EKS Cluster
Set up a Postgres database using a Helm Chart.

1. Create EKS Cluster
```bash
eksctl create cluster --name my-cluster --version 1.29 --region us-east-1 --nodegroup-name my-nodes --node-type t3.small --nodes 1 --nodes-min 1 --nodes-max 2
```

2. Setup your kube-config k8s
```
aws eks --region us-east-1 update-kubeconfig --name my-cluster
```

3. Create and install CSI Driver (Use this tutorial [Install CSI Driver](https://www.stacksimplify.com/aws-eks/kubernetes-storage/install-aws-ebs-csi-driver-on-aws-eks-for-persistent-storage/).
```
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
```
#### 2.- Set Up a Postgres Database with Helm Chart
1. Install Helm
```bash
curl -LO https://get.helm.sh/helm-v3.12.2-linux-amd64.tar.gz
```

2. Add the Bitnami Helm Repository
```
aws eks --region us-east-1 update-kubeconfig --name my-cluster
```
3. Install the PostgreSQL Chart
```
helm install my-postgresql oci://registry-1.docker.io/bitnamicharts/postgresql
```
This should set up a Postgre deployment at `<SERVICE_NAME>-postgresql.default.svc.cluster.local` in your Kubernetes cluster. You can verify it by running `kubectl svc`

By default, it will create a username `postgres`. The password can be retrieved with the following command:
```bash
export POSTGRES_PASSWORD=$(kubectl get secret --namespace default <SERVICE_NAME>-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

echo $POSTGRES_PASSWORD
```

<sup><sub>* The instructions are adapted from [Bitnami's PostgreSQL Helm Chart](https://artifacthub.io/packages/helm/bitnami/postgresql).</sub></sup>

4. Test Database Connection
The database is accessible within the cluster. This means that when you will have some issues connecting to it via your local environment. You can either connect to a pod that has access to the cluster _or_ connect remotely via [`Port Forwarding`](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)

* Connecting Via Port Forwarding
```bash
kubectl port-forward --namespace default svc/<SERVICE_NAME>-postgresql 5432:5432 &
    PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5432
```

* Connecting Via a Pod
```bash
kubectl exec -it <POD_NAME> bash
PGPASSWORD="<PASSWORD HERE>" psql postgres://postgres@<SERVICE_NAME>:5432/postgres -c <COMMAND_HERE>
```

5. Run Seed Files
We will need to run the seed files in `db/` in order to create the tables and populate them with data.

```bash
kubectl port-forward --namespace default svc/my-postgresql 5433:5432 &
    PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5433 < db/1_create_tables.sql
    PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5433 < db/2_seed_users.sql 
    PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U postgres -d postgres -p 5433 < db/3_seed_tokens.sql 
```

### 3. Running the Analytics Application Locally
In the `analytics/` directory:

1. Install dependencies
```bash
python -m pip install --upgrade pip

pip install -r analytics/requirements.txt
```
2. Run the application (see below regarding environment variables)
```bash
DB_USERNAME=postgres DB_PASSWORD=$POSTGRES_PASSWORD python analytics/app.py
```

3. Verifying The Application
* Generate report for check-ins grouped by dates
`curl <BASE_URL>/api/reports/daily_usage`

* Generate report for check-ins grouped by users
`curl <BASE_URL>/api/reports/user_visits`

### 4. Running the Analytics Application Locally
1. Apply deployment for your k8s cluster
```bash
kubectl apply -f deploy/
```

## 5: Setup CloudWatch Agent

1. Apply deployment for your k8s cluster
```bash
ClusterName=p3-cluster
RegionName=us-east-1
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml | sed 's/{{cluster_name}}/'${ClusterName}'/;s/{{region_name}}/'${RegionName}'/;s/{{http_server_toggle}}/"'${FluentBitHttpServer}'"/;s/{{http_server_port}}/"'${FluentBitHttpPort}'"/;s/{{read_from_head}}/"'${FluentBitReadFromHead}'"/;s/{{read_from_tail}}/"'${FluentBitReadFromTail}'"/' | kubectl apply -f -
```
