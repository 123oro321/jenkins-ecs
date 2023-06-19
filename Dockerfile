FROM jenkins/jenkins:2.401.1
RUN jenkins-plugin-cli --plugins "blueocean configuration-as-code"
COPY jenkins.yaml /etc/jenkins.yaml
ENV CASC_JENKINS_CONFIG /etc/jenkins.yaml