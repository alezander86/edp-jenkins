# Copyright 2020 EPAM Systems.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

# See the License for the specific language governing permissions and
# limitations under the License.
FROM quay.io/openshift/origin-cli:v3.11

# Jenkins LTS packages from
# https://pkg.jenkins.io/redhat-stable/
ENV JENKINS_VERSION=2 \
    HOME=/var/lib/jenkins \
    JENKINS_HOME=/var/lib/jenkins \
    JENKINS_UC=https://updates.jenkins.io \
    OPENSHIFT_JENKINS_IMAGE_VERSION=3.11 \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

LABEL k8s.io.description="Jenkins is a continuous integration server" \
      k8s.io.display-name="Jenkins 2" \
      openshift.io.expose-services="8080:http" \
      openshift.io.tags="jenkins,jenkins2,ci" \
      io.openshift.s2i.scripts-url=image:///usr/libexec/s2i

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# 8080 for main web interface, 50000 for slave agents
EXPOSE 8080 50000


RUN curl https://pkg.jenkins.io/redhat-stable/jenkins.repo -o /etc/yum.repos.d/jenkins.repo && \
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key && \
    yum update
    
RUN yum install -y centos-release-scl-rh-2-3.el7.centos

RUN yum install -y  epel-release-8-11.el8.noarch && \
    curl https://copr.fedorainfracloud.org/coprs/alsadi/dumb-init/repo/epel-7/alsadi-dumb-init-epel-7.repo -o /etc/yum.repos.d/alsadi-dumb-init-epel-7.repo && \
    #run yum update to avoid package version mismatch between i686 and other archs
    yum -y update && \
    x86_EXTRA_RPMS=(java-11-openjdk.i686 java-11-openjdk-devel.i686) && \
    INSTALL_PKGS=(dejavu-sans-fonts rsync gettext git tar zip unzip openssl bzip2 dumb-init java-11-openjdk java-11-openjdk-devel jenkins-2.263.1-1.1 nss_wrapper) && \
    yum -y --setopt=protected_multilib=false --setopt=tsflags=nodocs install "${INSTALL_PKGS[@]}" "${x86_EXTRA_RPMS[@]}" && \
    rpm -V "${INSTALL_PKGS[@]}" "${x86_EXTRA_RPMS[@]}" && \
    yum clean all  && \
    localedef -f UTF-8 -i en_US en_US.UTF-8

COPY ./contrib/openshift /opt/openshift
COPY ./contrib/jenkins /usr/local/bin
COPY ./contrib/s2i /usr/libexec/s2i
COPY release.version /tmp/release.version

RUN /usr/local/bin/install-plugins.sh /opt/openshift/base-plugins.txt && \
    # need to create <plugin>.pinned files when upgrading "core" plugins like credentials or subversion that are bundled with the jenkins server
    # Currently jenkins v2 does not embed any plugins, but for reference:
    # touch /opt/openshift/plugins/credentials.jpi.pinned && \
    rmdir /var/log/jenkins && \
    chmod -R 775 /etc/alternatives && \
    chmod -R 775 /var/lib/alternatives && \
    chmod -R 775 /usr/lib/jvm && \
    chmod 775 /usr/bin && \
    chmod 775 /usr/lib/jvm-exports && \
    chmod 775 /usr/share/man/man1 && \
    chmod 775 /var/lib/origin && \
    unlink /usr/bin/java && \
    unlink /usr/bin/jjs && \
    unlink /usr/bin/keytool && \
    unlink /usr/bin/pack200 && \
    unlink /usr/bin/rmid && \
    unlink /usr/bin/rmiregistry && \
    unlink /usr/bin/unpack200 && \
    unlink /usr/share/man/man1/java.1.gz && \
    unlink /usr/share/man/man1/jjs.1.gz && \
    unlink /usr/share/man/man1/keytool.1.gz && \
    unlink /usr/share/man/man1/pack200.1.gz && \
    unlink /usr/share/man/man1/rmid.1.gz && \
    unlink /usr/share/man/man1/rmiregistry.1.gz && \
    unlink /usr/share/man/man1/unpack200.1.gz && \
    chown -R 1001:0 /opt/openshift && \
    /usr/local/bin/fix-permissions /opt/openshift && \
    /usr/local/bin/fix-permissions /opt/openshift/configuration/init.groovy.d && \
    /usr/local/bin/fix-permissions /var/lib/jenkins && \
    /usr/local/bin/fix-permissions /var/log

VOLUME ["/var/lib/jenkins"]

ENV HELM_VERSION="v3.4.2"

RUN curl https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -o - | tar -xzO linux-amd64/helm > /usr/bin/helm \
    && chmod +x /usr/bin/helm \
    && rm -rf linux-amd64

USER jenkins
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/libexec/s2i/run"]
