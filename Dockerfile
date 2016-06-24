FROM quay.io/nordstrom/awscli:1.10.40
MAINTAINER Store Modernization Platform Team "invcldtm@nordstrom.com"

COPY apply-labels.sh /
CMD [ "/apply-labels.sh", "-t", "300s" ]
