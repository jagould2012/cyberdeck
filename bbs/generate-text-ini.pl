#!/usr/bin/perl
# generate-text-ini.pl - Create ctrl/text.ini with Cyberdeck colors
# Usage: perl generate-text-ini.pl > ctrl/text.ini

use strict;
use warnings;

# Ctrl-A character
my $CA = "\x01";

print "; Synchronet Text String Overrides\n";
print "; Cyberdeck color scheme: grayscale\n";
print "; Style: lowercase with bright white first letter\n";
print ";\n";

print "\n[default.js]\n";

# Shell prompt begin: gray bullet, bright white
# Original: "\x01-\x01c\xfe \x01b\x01h"
print "shell_prompt_begin = ${CA}-${CA}w\xfe ${CA}h${CA}w\n";

# Shell prompt middle: gray bullet, bright white  
# Original: " \x01n\x01c\xfe \x01h"
print "shell_prompt_middle = ${CA}n${CA}w\xfe ${CA}h${CA}w\n";

# Main menu prompt end - single backslash
# Original: " \x01n\x01c[\x01h@GN@\x01n\x01c] @GRP@\\ [\x01h@SN@\x01n\x01c] @SUB@: \x01n"
print "shell_main_prompt_end = ${CA}n${CA}w[${CA}h\@GN\@${CA}n${CA}w] \@GRP\@ [${CA}h\@SN\@${CA}n${CA}w] \@SUB\@: ${CA}n\n";

# File menu prompt end - single backslash
# Original: " \x01n\x01c(\x01h@LN@\x01n\x01c) @LIB@\\ (\x01h@DN@\x01n\x01c) @DIR@: \x01n"
print "shell_file_prompt_end = ${CA}n${CA}w(${CA}h\@LN\@${CA}n${CA}w) \@LIB\@ (${CA}h\@DN\@${CA}n${CA}w) \@DIR\@: ${CA}n\n";

# Menu labels - bright first letter, rest gray lowercase
print "Main = ${CA}h${CA}wM${CA}n${CA}wain\n";
print "File = ${CA}h${CA}wF${CA}n${CA}wile\n";

print "\n[js]\n";
print "; Global JS text overrides\n";