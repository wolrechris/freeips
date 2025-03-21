#!/bin/bash

# Configuration
version="0.2.0"
# Set the default hosts file to parse. Can be overwritten with --file.
hosts_file='/etc/hosts'
# Set the default output file to write to. Can be specified with
output_file="$0_$(date +"%Y-%m-%d_%H-%M-%S").log"
# Print to stdout instead of default file 
print=""
# Print ip addresses in use instead (inversion)
inuse=""
# Regex to identify subnet (must identify subnet of size /16 and
# include two dots for separation)
subnet="^10.81."
# Initialize some variables
free_only=""
used_ips=()
used_hosts=()

parse_file () {
	# Remove comments and sort file by ip address
	input_sorted=$(awk -v sn="$subnet" '
	/^#/ {next}
	$0 ~ sn {print}' "$hosts_file" | sort)

	# save used ips and hosts into arrays
	used_ips=($(echo "$input_sorted" | awk '{print $1}'))
	used_hosts=($(echo "$input_sorted" | awk '{$1=""; sub(/^ /, ""); print}'))
}

ips_in_block () {
	# Echo the amount of IPs in a given IP block
	echo $((for item in "${used_ips[@]}"; do
		echo "$item"
	done) | awk -F . '{print $3}' | grep "^$1" | wc -l)
}

print_block_ips () {
	# Prints free or used ip addresses within a /24 block.
	# $1 should be the "block number" and $2 either "free" or "used"
	# $3 passes the number of ips that are used
	prefix="${subnet:1}$1"
	# Stringified version of used_ips that only contains ips of this block
	used_ips_sub=$(
		for item in "${used_ips[@]}"; do
			echo "$item"
		done | grep -E "^$prefix"
	)
	found_used=0
	hits_first_cons=""
	i=0
	while [[ $found_used -lt $3 ]]; do
		# Set current IP only if it exists in used_ips_sub
		current_ip=$(echo "$used_ips_sub" | grep -o -E "^${prefix}\.${i}$")
		# Check if ip is a hit, depending on if searching for
		# used or free
		if [[ "$current_ip" ]]; then
			found_used=$(($found_used + 1))
			if [[ "$2" == "used" ]]; then
				# searching USED / something found
				if [[ -z $hits_first_cons ]]; then
					hits_first_cons="$prefix.$i"
				fi
			else
				# searching FREE / something found
				if [[ $hits_first_cons ]]; then
					print_range "$hits_first_cons" "$prefix.$(($i - 1))" "h"
					hits_first_cons=""
				fi
			fi
		else
			if [[ "$2" == "used" ]]; then
				# searching USED / nothing found
				if [[ $hits_first_cons ]]; then
					print_range "$hits_first_cons" "$prefix.$(($i - 1))" "h"
					hits_first_cons=""
				fi
			else
				# searching FREE / nothing found
				if [[ -z $hits_first_cons ]]; then
					hits_first_cons="$prefix.$i"
				fi
			fi
		fi
		i=$((i + 1))
	done
	# print out the last sequence of found IPs:
	if [[ $hits_first_cons ]]; then
		print_range "$hits_first_cons" "$prefix.$(($i - 1))" "h"
	fi
}

print_range () {
	# Prints out IP addresses between $1 and $2.
	# 3 states if they should be printed in a horizontal (+tabbed)
	# or vertical format
	if [[ "$3" == "v" ]]; then
		if [[ "$1" == "$2" ]]; then
			p2output "$1"
		else
			p2output "$1"
			p2output "     ..."
			p2output "$2"
		fi
	else
		if [[ "$1" == "$2" ]]; then
			p2output "		$1"
		else
			p2output "		$1 ... $2"
		fi
	fi
}

p2output () {
	# Print $1 to stdout or file
	if [ "$print" ]; then
		printf "%s\n" "$1"
	else
		printf "%s\n" "$1" >> "$output_file"
	fi
}

# Parse input paramenters
while [ $# -gt 0 ]; do
	case $1 in
		-f|--file) hosts_file="$2"; shift;;
		-F|--free-only) free_only=true;;
		-o|--out) output_file="$2"; shift;;
		-p|--print) print=true;;
		-h|--help) help=true;;
		-u|--inuse) inuse=true;;
		-s|--subnet) subnet="$2"; shift;;
		*) printf "Unknown parameter: $1\nTry \"$0 --help\" for usage info.\n"
	esac
	shift
done

# Check if specified subnet is valid
if [[ -z $(echo "$subnet" | grep -E '^\^[0-9]{1,3}\.[0-9]{1,3}\.') ]]; then
	printf "Not a valid subnet: $subnet\n"
	printf "Subnets must be /16 and in regex form (e.g. ^10.82.)\n"
	exit 1
fi

# Check if input file exists
if [ -f $hosts_file ]; then
	parse_file
else
	printf "File does not exist: $hosts_file\n"
	exit 1
fi

# Check incompatible flag combinations
if [[ $inuse && $free_only ]]; then
	printf "%s\n" "-u/--inuse and -F/--free-only are mutually exclusive."
	printf "Refer to $0 --help for usage instructions.\n"
	exit 1
fi

# Print help screen
if [[ $help ]]; then
	printf "%s\n\n" "$0 (v$version) help page. This tool helps you analyze Linux hosts files."
	printf "%s\n" "-f|--file <path>     Specify hosts input file (Default: $hosts_file)"
	printf "%s\n" "-o|--out <path>   Specify output file path (Default: $output_file)"
	printf "%s\n" "-s|--subnet          Specify the /16 subnet to check (Default: $subnet)"
	printf "%s\n" "-F|--free-only       Print only completely free /24 blocks"
	printf "%s\n" "-p|--print           Print to stdout instead of a file"
	printf "%s\n" "-h|--help            Show this page"
	printf "%s\n" "-u|--inuse           Show ip addresses that are in use"
	exit 0
fi

# Blank file if file output selected and file exists
if [[ -f $output_file && -z $print ]]; then
	printf "" > $output_file
fi

# Print header
if [[ $inuse ]]; then
	p2output "Summary of IP addresses IN USE as defined in $hosts_file:"
	p2output ""
else
	if [[ $free_only ]]; then
		p2output "Completely free /24 address blocks in $hosts_file:"
		p2output ""	
	else
		p2output "Summary of FREE IP addresses in $hosts_file:"
		p2output ""
	fi
fi

# Check /24 blocks
first_cons_free=""
for i in {0..255}; do
	used_in_block=$(ips_in_block $i)
	if [[ $used_in_block != "0" || $i == "255" ]]; then
		# Print two "edge blocks" of gap if gap is over or
		# the last block is reached
		if [[ $first_cons_free && -z $inuse ]]; then
			print_range "${subnet:1}$first_cons_free.0/24" "${subnet:1}$((i - 1)).0/24" "v"
			first_cons_free=""
		fi
		# Print the summary for blocks that are not empty
		if [[ $used_in_block != 0 && -z $free_only ]]; then
			if [ $inuse ]; then
				p2output "${subnet:1}$i.0/24: $(($used_in_block)) IPs used"
				print_block_ips $i "used" $used_in_block
			else
				p2output "${subnet:1}$i.0/24: $((256 - $used_in_block)) IPs free"
				print_block_ips $i "free" $used_in_block
			fi
		fi
	else
		# Identify if this is the first free block in a gap
		if [[ -z $first_cons_free ]]; then
			first_cons_free=$i
		fi

	fi
done
