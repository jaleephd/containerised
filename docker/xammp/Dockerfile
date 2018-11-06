FROM ubuntu:18.04

# Install wget and vim; curl and net-stats for XAMPP
RUN apt-get update && \
    apt-get -yq upgrade && \
	apt-get install -yq vim wget curl net-tools

# download installer
RUN wget https://www.apachefriends.org/xampp-files/7.2.10/xampp-linux-x64-7.2.10-0-installer.run
# run installer
RUN chmod +x xampp-linux-x64-7.2.10-0-installer.run
RUN ./xampp-linux-x64-7.2.10-0-installer.run --mode unattended

# enable access to ports
EXPOSE 80 443 3306

# to start web server:
#   /opt/lampp/lampp start
