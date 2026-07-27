source /home/beach/.env
source /home/beach/.bashrc

if [ -f /application/.beach-build-result.env ]; then
    source /application/.beach-build-result.env
fi