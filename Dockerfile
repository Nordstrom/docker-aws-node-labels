FROM nordstrom/util

RUN pip install awscli==1.9.11

COPY apply-labels.sh /

CMD [ "/apply-labels.sh", "-t", "300s" ]
