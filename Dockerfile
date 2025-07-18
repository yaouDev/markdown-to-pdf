# base package - maintained which is nice
FROM pandoc/latex

WORKDIR /app

# pandoc/latex uses default shell, but I want bash
# im stoopid, pandoc/latex defaults to alpine
RUN apk update && apk add bash

COPY entrypoint.sh /entrypoint.sh
COPY template/ /app/template/

# I messed up the line endings and am lazy so I'll just add a conversion here
RUN sed -i 's/\r$//' /entrypoint.sh

RUN chmod +x /entrypoint.sh

RUN env

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
