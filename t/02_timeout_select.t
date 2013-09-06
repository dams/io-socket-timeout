use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/tlib";
use TestTimeout;
use Test::Exception;


subtest 'test with no delays and no timeouts', sub {
TestTimeout->test( provider => 'Select',
                   connection_delay => 0,
                   read_delay => 0,
                   write_delay => 0,
                   callback => sub {
                       my ($client) = @_;
                       $client->print("OK\n");
                       my $response = $client->getline;
                       is $response, "SOK\n", "got proper response 1";
                       $client->print("OK2\n");
                       $response = $client->getline;
                       is $response, "SOK2\n", "got proper response 2";
                   },
                 );
};

use POSIX qw(ETIMEDOUT ECONNRESET);

subtest 'test with read timeout', sub {
TestTimeout->test( provider => 'Select',
                   connection_delay => 0,
                   read_timeout => 0.2,
                   read_delay => 3,
                   write_timeout => 0,
                   write_delay => 0,
                   callback => sub {
                       my ($client) = @_;
                       $client->print("OK\n");
                       my $response = $client->getline;
                       is $response, "SOK\n", "got proper response 1";
                       $client->print("OK2\n");
                       $response = $client->getline;
                       is $response, undef, "we've hit timeout";
                       is $!, 'Operation timed out', "and error is timeout";
                   },
                 );
};

subtest 'test with sysread timeout', sub {
TestTimeout->test( provider => 'Select',
                   connection_delay => 0,
                   read_timeout => 0.2,
                   read_delay => 3,
                   write_timeout => 0,
                   write_delay => 0,
                   callback => sub {
                       my ($client) = @_;
                       $client->print("OK\n");
                       my $buffer;
                       my $length_read = $client->sysread($buffer, 4);
                       is $length_read, 4, "got success";
                       is $buffer, "SOK\n", "got proper response 1";
                       $client->print("AA2\n");
                       my $buffer2;
                       $length_read = $client->sysread($buffer2, 5, $length_read);
                       is $length_read, undef, "we've hit timeout";
                       is $buffer2, undef, "buffer is undef";
                       is $!, 'Operation timed out', "and error is timeout";
                   },
                 );
};

done_testing;

