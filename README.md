## Freeips purpose and liminations

Freeips is a tool that helps you analyze /etc/hosts files from linux and unix machines. It can either print a summary of all IP addresses that are in use or all that are free.

Due to the specific usecase that this tool was developed for, it is mainly intended to be used in /16 subnets. While it can also be used in /24 subnets, the display options are not ideal.

## Usage

* -f|--file <path>     Specify hosts input file (Default: /etc/hosts)
* -o|--output <path>   Specify output file path (Default: ./freeips. sh_2025-03-21_16-26-05.log)
* -s|--subnet          Specify the /16 subnet to check (Default: ^10.81.)
* -F|--free-only       Print only completely free /24 blocks
* -p|--print           Print to stdout instead of a file
* -h|--help            Show this page
* -u|--inuse           Show ip addresses that are in use