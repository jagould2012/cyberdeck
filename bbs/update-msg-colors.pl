#!/usr/bin/perl
# update-msg-colors.pl - Transform Synchronet .msg/.asc files for Cyberdeck theme
# Usage: perl update-msg-colors.pl <file>

use strict;
use warnings;

my $file = $ARGV[0] or die "Usage: $0 <file>\n";

# Read entire file as binary
local $/;
open(my $fh, "<:raw", $file) or die "Cannot open $file: $!";
my $content = <$fh>;
close($fh);

# Step 1: Protect @-codes by replacing with placeholders
# @-codes can contain many characters including |, :, !, ., etc.
# Match @ followed by any characters (non-greedy) until the next @
# Use a unique marker that won't appear in the file
my @codes;
my $counter = 0;

# Use a different approach: capture everything between @ pairs
# The pattern matches @...@ where ... is any char except @ and newlines
$content =~ s/(\@[^\@\r\n]+\@)/
    push @codes, $1;
    "\x00PLACEHOLDER" . $counter++ . "END\x00";
/ge;

# Step 2: Lowercase regular ASCII text (A-Z only, not high ASCII graphics)
# But preserve Ctrl-A code letters (they come right after \x01)
$content =~ s/(?<!\x01)([A-Z])/lc($1)/ge;

# Step 3: Restore @-codes from the array (preserving original case)
for (my $i = 0; $i < @codes; $i++) {
    $content =~ s/\x00placeholder${i}end\x00/$codes[$i]/i;
}

# Step 4: Convert to Cyberdeck color scheme
# Target palette: white, gray, dark gray, brown (ANSI color 6)
#
# Synchronet Ctrl-A color codes:
# k/K=black, r/R=red, g/G=green, y/Y=yellow(brown), b/B=blue,
# m/M=magenta, c/C=cyan, w/W=white
# H=high intensity, N=normal, 0-7=background colors

# Convert command key pattern: high-white single letter followed by normal
# Pattern 1: \x01h\x01w[letter]\x01n -> \x01y[letter]\x01n (brown command key)
$content =~ s/\x01h\x01w([a-z])\x01n/\x01y$1\x01n/g;
$content =~ s/\x01H\x01W([a-z])\x01N/\x01Y$1\x01N/g;
$content =~ s/\x01h\x01w([a-z])\x01N/\x01y$1\x01N/g;
$content =~ s/\x01H\x01W([a-z])\x01n/\x01Y$1\x01n/g;

# Pattern 2: \x01H\x01C[letter]\x01N (high cyan letter) -> brown
$content =~ s/\x01H\x01C([a-z])\x01N/\x01Y$1\x01N/g;
$content =~ s/\x01H\x01C([a-z])\x01n/\x01Y$1\x01n/g;
$content =~ s/\x01h\x01c([a-z])\x01n/\x01y$1\x01n/g;

# Pattern 3: Some menus use \x01Y[letter]\x01Y or \x01Y[letter]\x01N - already brown, keep as is

# Also handle symbols as command keys: *, /, [, ], {, }, +, -, =, &, !, ^
$content =~ s/\x01h\x01w([\*\/\[\]\{\}\+\-\=\&\!\^])\x01n/\x01y$1\x01n/g;
$content =~ s/\x01H\x01W([\*\/\[\]\{\}\+\-\=\&\!\^])\x01N/\x01Y$1\x01N/g;
$content =~ s/\x01h\x01w([\*\/\[\]\{\}\+\-\=\&\!\^]) /\x01y$1 /g;
$content =~ s/\x01H\x01W([\*\/\[\]\{\}\+\-\=\&\!\^]) /\x01Y$1 /g;

# Handle /a, /l, /g style commands  
$content =~ s/\x01h\x01w(\/[a-z])\x01n/\x01y$1\x01n/g;
$content =~ s/\x01H\x01W(\/[a-z])\x01N/\x01Y$1\x01N/g;

# Handle ^k style commands (ctrl-key)
$content =~ s/\x01h\x01w(\^[a-z])\x01n/\x01y$1\x01n/g;
$content =~ s/\x01H\x01W(\^[a-z])\x01N/\x01Y$1\x01N/g;

# Cyberdeck color conversions for other elements:
# First, handle high-intensity color combinations
$content =~ s/\x01H\x01Y/\x01H\x01K/g;  # bright yellow -> dark gray
$content =~ s/\x01h\x01y/\x01h\x01k/g;  # bright yellow -> dark gray (lowercase)
$content =~ s/\x01y\x01h/\x01w\x01h/g;  # yellow+high (accent text) -> white+high
$content =~ s/\x01Y\x01H/\x01W\x01H/g;  # Yellow+High (accent text) -> White+High
$content =~ s/\x01H\x01G/\x01H\x01W/g;  # bright green -> bright white
$content =~ s/\x01H\x01C/\x01Y/g;       # bright cyan -> brown
$content =~ s/\x01H\x01B/\x01H\x01K/g;  # bright blue -> dark gray
$content =~ s/\x01H\x01R/\x01H\x01K/g;  # bright red -> dark gray
$content =~ s/\x01H\x01M/\x01H\x01K/g;  # bright magenta -> dark gray

# Regular color conversions
$content =~ s/\x01b/\x01w/g;   # blue -> gray
$content =~ s/\x01B/\x01W/g;   # Blue -> Gray
$content =~ s/\x01c/\x01w/g;   # cyan -> gray
$content =~ s/\x01C/\x01W/g;   # Cyan -> Gray
$content =~ s/\x01g/\x01w/g;   # green -> gray
$content =~ s/\x01G/\x01W/g;   # Green -> Gray
$content =~ s/\x01r/\x01k/g;   # red -> black
$content =~ s/\x01R/\x01K/g;   # Red -> Black
$content =~ s/\x01m/\x01k/g;   # magenta -> black
$content =~ s/\x01M/\x01K/g;   # Magenta -> Black

# Background colors: convert colored backgrounds to black
$content =~ s/\x014/\x010/g;   # blue bg -> black bg
$content =~ s/\x011/\x010/g;   # red bg -> black bg
$content =~ s/\x012/\x010/g;   # green bg -> black bg
$content =~ s/\x013/\x010/g;   # yellow bg -> black bg
$content =~ s/\x015/\x010/g;   # magenta bg -> black bg
$content =~ s/\x016/\x010/g;   # cyan bg -> black bg

# Write output
open(my $out, ">:raw", $file) or die "Cannot write $file: $!";
print $out $content;
close($out);