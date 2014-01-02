/etc/ssh/sshd_config:
  file.managed:
    - source: salt://etc/ssh/sshd_config
    - template: jinja
  require:
    - pkg: openssh-server
