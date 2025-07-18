# base package - maintained which is nice
FROM pandoc/latex

WORKDIR /app

# pandoc/latex uses default shell, but I want bash
# apparently it wants me to use the full path
RUN /usr/bin/apt-get update && /usr/bin/apt-get install -y bash

COPY entrypoint.sh /entrypoint.sh
COPY template/ /app/template/

# I messed up the line endings and am lazy so I'll just add a conversion here
RUN sed -i 's/\r$//' /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
