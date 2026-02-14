#!/usr/bin/env python3
"""Generate architecture diagram for the terraform-aws-ec2-rocky9-fips module.

Usage:
    # Via Makefile (recommended - handles venv automatically):
    make diagram

    # Manual:
    cd docs
    ../.venv/bin/python generate-diagram.py

Produces: docs/architecture.png
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2
from diagrams.aws.management import Cloudwatch, SystemsManager
from diagrams.aws.network import VPC
from diagrams.aws.security import IAM, IAMRole
from diagrams.aws.integration import SNS
from diagrams.aws.storage import EBS

graph_attr = {
    "fontsize": "14",
    "fontname": "Helvetica",
    "bgcolor": "white",
    "pad": "0.5",
    "label": "terraform-aws-ec2-rocky9-fips\nby Ironsmith",
    "labelloc": "t",
    "labeljust": "c",
}

optional_cluster_attr = {
    "style": "dashed",
    "color": "#888888",
    "fontcolor": "#888888",
    "fontsize": "11",
}

with Diagram(
    "",
    filename="architecture",
    show=False,
    direction="TB",
    graph_attr=graph_attr,
    outformat="png",
):
    # Core infrastructure
    with Cluster("VPC (derived from subnet_id)"):
        with Cluster("Subnet"):
            sg = IAM("Security Group\n(SSH conditional)")
            instance = EC2(
                "EC2 Instance\nRocky Linux 9 FIPS\nIMDSv2 enforced"
            )
            ebs = EBS("EBS gp3\nEncrypted")

    sg >> instance
    instance - ebs

    # IAM (conditional)
    with Cluster("IAM (conditional)", graph_attr=optional_cluster_attr):
        role = IAMRole("Instance Role\n+ Profile")

    role >> Edge(style="dashed", label="assume-role") >> instance

    # CloudWatch (optional)
    with Cluster(
        "CloudWatch (opt-in)", graph_attr=optional_cluster_attr
    ):
        logs = Cloudwatch("Log Group\nDashboard")

    instance >> Edge(style="dashed", label="logs &\nmetrics") >> logs

    # SSM (optional)
    ssm = SystemsManager("SSM\n(opt-in)")
    instance >> Edge(style="dashed") >> ssm

    # Security Alarms (optional)
    with Cluster(
        "Security Alarms (opt-in)", graph_attr=optional_cluster_attr
    ):
        sns = SNS("SNS Topic\n+ Email")

    logs >> Edge(style="dashed", label="metric\nfilters") >> sns

    # DLM Snapshots (optional)
    dlm = EBS("DLM Snapshots\n(opt-in)")
    ebs >> Edge(style="dashed", label="daily") >> dlm
