FROM nordstrom/util

RUN pip install awscli==1.9.11

COPY apply-labels.sh /

ENTRYPOINT ["/apply-labels.sh", "-t"]
CMD ["300s"]
