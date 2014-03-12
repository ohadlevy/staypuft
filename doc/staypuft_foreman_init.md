# Staypuft Foreman initial setup design

## What we need (ordered by priority):

* automatic setup with minimal user interaction (max 1 answer whether he wants automatic setup or advanced configuration wizard)
* wizard must be easy to use for people who don't know foreman
* it must be possile to run in advanced mode (post April) to customize all values
* it should be easy to change configuration after initial setup
* must work disconnected

## What we need to setup

* Subnet 
  * create a subnet that does not exist yet (free IP validation) - we need unassigned NIC or should we try to create new one?
  * allow to skip if user want to use existing (post April)
  * selection of any existing subnet*
* Domain
  * based on machine domain
  * do we need to allow using other domain (post April)
* DHCP, DNS, TFTP parameters (based on Subnet and Domain)
* Operatingsystem
  * can we assume latest released RHEL only?
  * should be the same as on provisioning machine
* Provisioning template
  * should be default, we just have to link with OS
* Parition table
  * should be default, we just have to link with OS
* Installation media*
* RHN setup*

\* seems as part of staypuft wizard - see wireframes [1]

## Option A - installer (later kafo based)

### Installer workflow

I suppose we can run arbitrary script before or after foreman installation (using puppet-foreman* modules). Also these scripts should be able to share some values easily. I'm sure we can do this with kafo and it should be easy even with existing foreman_server.sh in Astapor.

1. installer is ran without any specific parameters
2. kafo 'pre hook' (or just simply script) creates new network, see step2 in OptionB for more details
3. same hook configures all values for DNS/DHCP parameters (see OptionB example for the list) based on $this machine environment and network it created in step 2
4. runs installation which setup DNS/DHCP/TFTP and foreman itself
5. kafo 'post hook' (or another script for Astapor installer) creates and assigns all models in foreman using foreman API, which basically duplicates foreman_setup logic

For customization user could set any parameter (only if based on kafo) and hook from step 2 would first check whether user wants some explicit value or hook should generate it.

### Evaluation

\+ Pre-set answer file for things like fixed values like subnet name<br />
\+ Kafo already supports system checks, pre and post installer hooks that could do the heavylifting<br />
\+ Therefore can hook to get answers before installation and use them after seed is complete<br />
\+ We'd get resulting configuration before foreman is visited for the first time<br />
\+ Runs as root so no permission escalation required<br />
\+ We don't have to use foreman_setup but we still can and it would have predefined many of default data there<br />
\- Easy only if everything is on one machine (which is the case for April for sure and probably even post April)<br/ >
\- Not that fancy as WebUI<br />
\- Does not have direct access to Foreman models, would use API probably (on the other hand less prone to rebase issues, API is meant to be stable)<br />
\- Duplicates the same logic present in foreman_setup<br />

Example:

    stapuft-installer                             # would try to detect and creating everything automatically
    stapuft-installer --subnet='192.168.123.0/24' # modify particular parameter
    stapuft-installer --interactive               # allow user to modify any parameter using wizard however pre hooks are executed before wizard, so default subnets would be created unless user specified some params alongside with --interactive option

## Option B - enhanced foreman_setup

### Existing foreman_setup workflow

Requires host to self-register in foreman (first puppet run) and upload facts (existing networks), Foreman setup read /etc/resolv.conf to get nameserver. Operatingssytem is created by first puppet run on provisioning host. You select network on first screen (based on host first puppet run). On second screen a domain and subnet is configured (based on facts again). We are missing gateway (not part of default facts) and start/end IPs. Installer by default does not set DHCP (interface needed, gateway IP etc) and DNS (zone name needed etc). Finally installation media form is displayed. This step creates Installation media, associates provisioning templates, partition tables etc. Activation key info is stored as hostgroup parameters.

This command is generated to configure foreman provisioning with DHCP

    foreman-installer \
      --enable-foreman-proxy \
      --foreman-proxy-tftp=true \
      --foreman-proxy-tftp-servername=192.168.122.102 \
      --foreman-proxy-dhcp=true \
      --foreman-proxy-dhcp-interface=eth0 \
      --foreman-proxy-dhcp-gateway=192.168.122.1 \
      --foreman-proxy-dhcp-range=" " \
      --foreman-proxy-dhcp-nameservers="192.168.122.102" \
      --foreman-proxy-dns=true \
      --foreman-proxy-dns-interface=eth0 \
      --foreman-proxy-dns-zone=example.com \
      --foreman-proxy-dns-reverse=122.168.192.in-addr.arpa \
      --foreman-proxy-dns-forwarders=192.168.122.1 \
      --foreman-proxy-dns-forwarders=192.168.122.2 \
      --foreman-proxy-foreman-base-url=https://test2.example.com \
      --foreman-proxy-oauth-consumer-key=z7zPMKXCACWtne4hE4xfmALnjvMzryPe \
      --foreman-proxy-oauth-consumer-secret=GwegrCMvrShqsmuMx9ZHDm7PoaszoRaX


### Ehanced foreman_setup workflow

Foreman would not allow to use UI without answering question "Do you want to setup default provisioning or you prefer advanced configuration wizard". If user choose default provisioning, all foreman_steps should be done automatically.


It would (using dynflow to maintain order):

1. run puppet on localhost
2. create new network just for foreman provisioning (this may be tricky - new virtual interface? use rather NIC without IP assigned? second ip on first device? unused range detection, ...)
3. create domain based on facter || example.com (same as foreman_setup suggests)
4. create subnet, uses name "default", all other is generated based on step 2
5. runs installer again with command generated (view _step3.html.erb in foreman_setup), preferably by any puppetrun method (for April, running shell on same machine should be enough)
6. we should provide installation media on provisioning machine so it could work without internet access, therefore we can setup this installation media (I suppose we can install just RHEL here?)

User still can choose not to use default provisioning and use foreman_setup as they do now.

### Evaluation

\+ We have JS and other web goodies to make advanced form easy to use<br />
\+ We could use dynflow to model workflow<br />
\+ With orchestration and SSH setup it could trigger configration on remote foreman-proxy (is this needed?)<br />
\- Would have to run commands under root user<br />
\- Foreman must be already running, which could possibly cause some troubles (foreman listens on wrong device)<br />
\- Would have to run installer at least once again<br />

## Option AB (various combinations)

Installer would create all things such as network and install DNS/DHCP etc. It would also create Provisioner (which is used by foreman_setup, however there's no API) so in UI it would look like foreman_setup was used. We could use foreman_setup to modify provisioning setup for this Provisioner later.

Or we could just predefine all required things and setup provisioning services and let foreman_setup to skip on step 4 where user defines installation media and everything is linked together (so we wouldn't duplicate that in installer).

## Option C - seed (rake task as a part of installation)

Probably not going to happen, I just wanted to mention it

\+ Easy to rerun from WebUI programatically if needed<br />
\- Hard to allow customization, it would create something that user has to remove/modify later in WebUI<br />

Example:

    staypuft-installer                # installs and runs rake db:seed as usual
    staypuft-installer --seed=another # would use another seed set, still no interactivity (e.g. existing subnet)


## Links

[1] http://file.bos.redhat.com/~lsurette/RHOS/2014-03-03_ofi-ui_wireframes.pdf
