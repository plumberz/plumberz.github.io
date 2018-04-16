# How To Build
After having installed docker CE and started the docker daemon ( ```sudo systemctl start docker``` ), edit the Dockerfile as needed to add stack or package dependencies and then build it (from the directory where it is):
```
sudo docker build . --tag=haskell-pt
sudo docker run -ti haskell-pt
```
This way you'll get a shell inside the container, the _./code_ directory will be mounted as _/code_ and you'll have stack installed to run your code.
