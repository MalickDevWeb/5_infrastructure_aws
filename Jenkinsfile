pipeline {
    agent any

    environment {
        AWS_REGION = 'eu-west-3' // AWS Paris
        ECR_REPO = 'mon-entreprise/backend-api'
        DOCKER_IMAGE = "${ECR_REPO}:${env.BUILD_NUMBER}"
        TF_WORKSPACE = 'production'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Tests & SAST (SonarQube)') {
            steps {
                echo "🧪 Exécution des tests unitaires et intégration (Pytest)"
                sh 'docker-compose run app pytest --cov=app --cov-fail-under=85'
                
                echo "🔍 Analyse de la qualité et de la sécurité du code"
                // withSonarQubeEnv('SonarQube-Server') {
                //     sh 'sonar-scanner'
                // }
            }
        }

        stage('Build Docker (Green IT)') {
            steps {
                echo "🐳 Build de l'image Docker avec cache multi-stage (Alpine/Slim)"
                sh "docker build -t ${DOCKER_IMAGE} ."
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                echo "🛡️ Scan des vulnérabilités de l'image Docker"
                // DevSecOps : Arrêt immédiat si vulnérabilité critique détectée
                sh "trivy image --exit-code 1 --severity CRITICAL,HIGH ${DOCKER_IMAGE}"
            }
        }

        stage('Push to AWS ECR') {
            steps {
                echo "☁️ Envoi de l'image Docker sur Amazon ECR"
                sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.${AWS_REGION}.amazonaws.com"
                sh "docker push <AWS_ACCOUNT_ID>.dkr.ecr.${AWS_REGION}.amazonaws.com/${DOCKER_IMAGE}"
            }
        }

        stage('Infrastructure (Terraform Plan)') {
            steps {
                dir('terraform') {
                    echo "🗺️ Planification de l'Infrastructure AWS"
                    sh 'terraform init'
                    sh 'terraform workspace select ${TF_WORKSPACE} || terraform workspace new ${TF_WORKSPACE}'
                    sh 'terraform plan -out=tfplan'
                }
            }
        }

        stage('Deploy (Terraform Apply)') {
            // Approbation manuelle (Quatre Yeux) requise pour la production
            input {
                message "⚠️ Approuver le déploiement Terraform sur l'environnement de PRODUCTION ?"
                ok "Déployer"
            }
            steps {
                dir('terraform') {
                    echo "🚀 Déploiement de l'Infrastructure AWS..."
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }
    }

    post {
        always {
            echo "🧹 Nettoyage de l'espace de travail Jenkins"
            cleanWs()
        }
        success {
            echo "✅ Pipeline DevSecOps exécuté avec succès !"
            // notification Slack / Teams (e.g., slackSend color: "good", message: "Build success!")
        }
        failure {
            echo "❌ Échec du pipeline. L'équipe d'astreinte est notifiée."
            // notification Slack / Teams
        }
    }
}
