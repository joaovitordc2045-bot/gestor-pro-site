GESTOR PRO - PUBLICACAO DO SITE

PRIMEIRA PUBLICACAO:
1. Extraia esta pasta para o computador.
2. Dê dois cliques em PUBLICAR-SITE.bat.
3. O script:
   - verifica Git e GitHub CLI;
   - usa sua autorizacao do GitHub;
   - cria o repositorio joaovitordc2045-bot/gestor-pro-site;
   - envia todos os arquivos do site;
   - ativa o GitHub Pages;
   - configura gestorpro.log.br como dominio personalizado;
   - abre o Registro.br para a configuracao final do DNS.

DNS:
A configuracao no Registro.br precisa ser feita somente uma vez.
Leia CONFIGURAR-DNS-REGISTROBR.txt.

ATUALIZACOES FUTURAS:
Depois de alterar qualquer arquivo do site, dê dois cliques novamente em
PUBLICAR-SITE.bat. Ele atualiza o mesmo repositorio e o mesmo site.

OBSERVACAO SOBRE DOWNLOADS:
Os arquivos Gestor-Pro-Setup.exe e Gestor-Pro.apk ainda nao estao dentro
deste pacote. Os botoes do site ja estao preparados para eles.
Para arquivos grandes, e melhor publicarmos os instaladores em GitHub Releases
e apontar os botoes do site para as Releases.
