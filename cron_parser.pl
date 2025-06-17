#!/usr/bin/env perl
use strict;
use warnings;
use DateTime;
use DateTime::Event::Cron;

# Get the cron expression from the command line argument
my $cron_expression = shift @ARGV;
die "Usage: $0 '<cron_expression>'\n" unless $cron_expression;

# Create a new DateTime object for the current time
my $now = DateTime->now();

# Parse the cron expression
my $cron_event = DateTime::Event::Cron->new(cron => $cron_expression);
my $next_execution = $cron_event->next($now);

# Print the next execution time as a Unix timestamp
print $next_execution->epoch(), "\n";
