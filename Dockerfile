FROM nordstrom/util:2015-10-06

COPY apply-labels.sh /

ENTRYPOINT [ "/apply-labels.sh" ]
CMD [ "" ]
