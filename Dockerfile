FROM nordstrom/util:2015-12-08

RUN pip install awscli==1.9.11

COPY apply-labels.sh /

ENTRYPOINT [ "/apply-labels.sh" ]
CMD [ "" ]
