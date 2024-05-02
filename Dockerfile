FROM docker.io/library/python:alpine

RUN apk update
RUN apk add py-pip apk-cron curl openssl bash

RUN pip install -U pip
RUN pip install awscli

RUN rm -rf /var/cache/apk/*

ADD app /app
ADD Dockerfile /

ENTRYPOINT ["/app/start.sh"]
