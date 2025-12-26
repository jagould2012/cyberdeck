#!/usr/bin/perl
# update-text-dat.pl - Convert Synchronet text.dat colors to Cyberdeck grayscale theme
# Usage: perl update-text-dat.pl <text.dat>
#
# In text.dat, color codes are literal strings like \1c \1g \1b etc.
# (backslash, one, letter) - NOT escape sequences
#
# Cyberdeck color scheme:
# - White (w/W) for normal text and prompts
# - Dark gray (k with h) for accents
# - Command key colors are handled by attr.ini, not text.dat

use strict;
use warnings;

my $file = $ARGV[0] or die "Usage: $0 <text.dat>\n";

# Read entire file
local $/;
open(my $fh, "<", $file) or die "Cannot open $file: $!";
my $content = <$fh>;
close($fh);

# In text.dat, color codes are literal text: \1X (backslash, 1, letter)
# We need to match the literal backslash, so we escape it as \\

# Convert cyan to white
$content =~ s/\\1c/\\1w/g;
$content =~ s/\\1C/\\1W/g;

# Convert blue to white
$content =~ s/\\1b/\\1w/g;
$content =~ s/\\1B/\\1W/g;

# Convert green to white
$content =~ s/\\1g/\\1w/g;
$content =~ s/\\1G/\\1W/g;

# Convert yellow to white (prompts, headers - command keys use attr.ini)
$content =~ s/\\1y/\\1w/g;
$content =~ s/\\1Y/\\1W/g;

# Convert red to dark gray (will show with high intensity)
$content =~ s/\\1r/\\1k/g;
$content =~ s/\\1R/\\1K/g;

# Convert magenta to dark gray
$content =~ s/\\1m/\\1k/g;
$content =~ s/\\1M/\\1K/g;

# Write output
open(my $out, ">", $file) or die "Cannot write $file: $!";
print $out $content;
close($out);

print "Converted colors in $file to Cyberdeck grayscale theme\n";