# Colors made a little easier
restore='\033[0m'
black='\033[0;30m'
red='\033[0;31m'
green='\033[0;32m'
brown='\033[0;33m'
blue='\033[0;34m'
purple='\033[0;35m'
cyan='\033[0;36m'
light_gray='\033[0;37m'
dark_gray='\033[1;30m'
light_red='\033[1;31m'
light_green='\033[1;32m'
yellow='\033[1;33m'
light_blue='\033[1;34m'
light_purple='\033[1;35m'
light_cyan='\033[1;36m'
white='\033[1;37m'


MAINTAINER_EMAIL='bporter@instructure.com'
RUBY_VER='2.1.6'

canvasdir="$HOME"
checkoutname="canvas-lms"
canvaslocation="${canvasdir}/${checkoutname}"

error ()
{
    echo -e "${red}${1}${restore}" >&2
}

die ()
{
    error "$1" >&2
    exit 1
}

white ()
{
    echo -e "${white}${1}${restore}"
}

green ()
{
    echo -e "${green}${1}${restore}"
}

cyan ()
{
    echo -e "${cyan}${1}${restore}"
}

red ()
{
    echo -e "${red}${1}${restore}"
}

yellow ()
{
    echo -e "${yellow}${1}${restore}"
}

