package TestTimeout;

use strict;
use warnings;

use Test::More;
use Test::Exception;
use IO::Socket::Timeout;
use Test::TCP;
use POSIX qw(ETIMEDOUT ECONNRESET strerror);
use Exporter 'import';

require bytes;

sub create_server_with_timeout {
    my ($connection_delay, $read_delay, $write_delay) = @_;

    # Warning:
    # $read_delay and $write_delay are seen from the *client* point of view

    Test::TCP->new(
        code => sub {
            my $port   = shift;
            my $socket = IO::Socket::INET->new(
                Listen    => 5,
                Reuse     => 1,
                Blocking  => 1,
                LocalPort => $port
            ) or die "ops $!";

            my $buffer;
            while (1) {
               # First, establish connection
                my $client = $socket->accept();
                $client or next;

                # Then get data (with delay)
                if ( defined (my $message = <$client>) ) {
                    my $response = "S" . $message;
                    print $client $response;
                    $message = <$client>;
                    $response = "S" . $message;
                    sleep($read_delay);
                    print $client $response;
                }
                $client->close();
            }
        },
    );
}

sub test {
    my $class = shift;
    my %p = @_;

    my $server = create_server_with_timeout( $p{connection_delay},
                                             $p{read_delay},
                                             $p{write_delay},
                                           );

    my $client = IO::Socket::INET->new::with::timeout(
        PeerHost        => '127.0.0.1',
        PeerPort        => $server->port,
        $p{connection_timeout} ? (Timeout => $p{connection_timeout} ) : (),
        TimeoutStrategy => $p{provider},
        TimeoutRead => $p{read_timeout},
        TimeoutWrite => $p{write_timeout},
    );

    my $etimeout = strerror(ETIMEDOUT);
    my $ereset   = strerror(ECONNRESET);
    $p{callback}->($client, $etimeout, $ereset);
}


1;
