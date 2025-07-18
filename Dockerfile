# base package - maintained which is nice
FROM pandoc/latex

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
COPY template/ /app/template/

# I messed up the line endings and am lazy so I'll just add a conversion here
RUN sed -i 's/\r$//' /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
