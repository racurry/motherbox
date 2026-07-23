# Set up NPM_TOKEN if .npmrc exists.
if [ -f ~/.npmrc ]; then
  export NPM_TOKEN=`sed -n -e '/_authToken/ s/.*\= *//p' ~/.npmrc`
fi
