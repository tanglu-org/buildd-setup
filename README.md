# Tanglu Buildd Provisioning

## Set up a new builder

### Set up a system to host the builder
Install a buildd host using one of our supported releases:
   * Tanglu Bartholomea (2.0)
   * Tanglu Chromodoris
   * Debian Jessie

For more information see README.host.md

### Generate the Builder Keys
- Note1: The rng-tools and urandom may help if you don't have enough entropy
         (use with care and inform yourself about what these tools do before using them!).
- Note2: During provisioning ansible will install haveged in the builders to
         help with automated key generation that's needed for sbuild internals.
         You might not want to generate the Builder PGP and SSL keys on a
         provisioned builder.

Run
 ```
 gpg --gen-key
 ```

Select RSA(4) and a length of 4096 bit.
You got the name of an element as buildd name.
The name should be: `"Tanglu <element> Buildd"`, e.g. "Tanglu Helium Buildd".
The email address should be `"<element>@buildd.tanglu.org"`, e.g. "helium@buildd.tanglu.org".
Set expiration date to 1-5 years, don't use a passphrase.

Export the pgp secret and public key:
 ```
 gpg --export-secret-key -a <element>@buildd.tanglu.org > <element>.sec && \
 gpg --armor --export "<element>@buildd.tanglu.org" > <element>.pgp && \
 chmod go-rwx *.sec
 ```

Create a debile xmlrpc ssl key and cert:
 ```
 openssl req -utf8 -nodes -newkey rsa:4096 -sha256 -x509 -days 7300 \
 -subj "/C=NT/O=Tanglu Project/OU=Package Build Service/CN=<element>/emailAddress=<element>@buildd.tanglu.org" \
 -keyout <element>.key -out <element>.crt && \
 chmod go-rwx *.key
 ```

Now put all the generated keys in ansible/keys/ where the provisioning
will pick them up

### Provision a builder

For an intro into ansible, visit http://www.ansible.com/how-ansible-works

#### Quick Intro

To use ansible for provisioning, the builder needs to have a ssh accessible
user with sudo permissions.

Add the Location of the builder to the inventory in /etc/ansible/hosts
 ```
 [ tanglu-buildd ]
 <builder address>
 ```

Provision the builder:
 ```
 ansible-playbook -K -u <remote-user> -l <builder address> ansible/playbook.yml
 ```
Ansible will ask you for the sudo password of the remote user.

Now sit back and watch as the builder gets set up ;)

Once ansible finishes the builder should be restarted so systemd can properly
start the debile-slave service. After this the builder should be ready and ask
the master for new jobs.

## Migrate an existing builder

Back up any settings that are not covered by the ansible provisioning

Back up the builder keys:
 ```
 /srv/buildd/<element>.key
 /srv/buildd/<element>.crt
 /srv/buildd/<element>.pgp
 ```

You will need to export the secret builder pgp key, for that log into the
builder, then
 ```
 sudo -u buildd -i
 gpg --export-secret-key -a <element>@buildd.tanglu.org > /srv/buildd/<element>.sec
 ```
then backup `/srv/buildd/<element>.sec`

Put all keys in ansible/keys/
The provisioning will import the keys into the buildd from there

## Vagrant

For testing/development purposes you can set up a Virtualbox VM using vagrant

To do this you will need to add a tanglu box first, e.g.:
http://yofel.net/tanglu/vagrant/tanglu-2.0-amd64.box

then run
 ```
 vagrant up
 ```
