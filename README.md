
# DevOps Assignment - AWS Fargate with Load Balancer

 Overview
This project deploys a containerized Node.js application to AWS ECS Fargate. It uses **Terraform** for Infrastructure as Code (IaC) and **GitHub Actions** for CI/CD.

**Advanced Implementation:**
I have included an **Application Load Balancer (ALB)**. This improves security and reliability by:
* Allowing access on standard HTTP Port 80 (instead of 8080).
* Performing health checks on the container before routing traffic.

 Architecture
1.  **Code Push:** pushes code to GitHub.
2.  **CI/CD:** GitHub Actions builds the Docker image and pushes it to Amazon ECR.
3.  **Deployment:** GitHub Actions updates the ECS Task Definition.
4.  **Traffic Flow:** User -> Application Load Balancer (Port 80) -> Fargate Container (Port 8080).

 How to Test
1.  **Main Application:** Access via the Load Balancer URL.
    * `http://devops-assignment-lb-1397550039.ap-south-1.elb.amazonaws.com/`
2.  **Health Check:**
    * `http://devops-assignment-lb-1397550039.ap-south-1.elb.amazonaws.com/health`

 Technologies
* **Compute:** AWS ECS Fargate
* **Networking:** VPC, Security Groups, Application Load Balancer (ALB)
* **CI/CD:** GitHub Actions
* **IaC:** Terraform
* **Container:** Docker, Amazon ECR
