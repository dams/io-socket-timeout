package IO::Socket::Timeout::Strategy::SetSockOpt;

use strict;
use warnings;
use Time::HiRes;

use Class::Method::Modifiers qw(install_modifier);
use POSIX qw(ETIMEDOUT ECONNRESET);
use Config;
use Carp;
use Socket;

use base qw(IO::Socket::Timeout::Strategy);

# ABSTRACT: proxy to read/write using IO::Select as a timeout provider

sub apply_to_class {
    my $class = shift;
    my ($into, $timeout_read, $timeout_write) = @_;

    $class->SUPER::apply_to_class(@_);

    $Config{osname} eq 'netbsd'
      and croak "NetBSD is not supported yet";
    $Config{osname} eq 'solaris'
      and croak "Solaris is not supported yet";

    my @wrap_read_functions = qw(getc getline getlines);
    my @wrap_read_functions_with_buffer = qw(recv sysread read);
    my @wrap_write_functions = qw( ungetc print printf say truncate);
    my @wrap_write_functions_with_buffer = qw(send syswrite write);

    if ($timeout_read) {
        install_modifier($into, 'around', $_, \&wrapper)
          foreach @wrap_read_functions, @wrap_read_functions_with_buffer;
    }

    if ($timeout_write) {
        install_modifier($into, 'around', $_, \&wrapper)
          foreach @wrap_write_functions, @wrap_write_functions_with_buffer;
    }
}

sub apply_to_instance {
    my ($class, $instance, $into, $timeout_read, $timeout_write) = @_;
    ${*$instance}{__timeout_read__} = $timeout_read;
    ${*$instance}{__timeout_write__} = $timeout_write;
    ${*$instance}{__is_valid__} = 1;

    if ($timeout_read) {
        my $seconds  = int( $timeout_read );
        my $useconds = int( 1_000_000 * ( $timeout_read - $seconds ) );
        my $timeout  = pack( 'l!l!', $seconds, $useconds );
        $instance->setsockopt( SOL_SOCKET, SO_RCVTIMEO, $timeout )
          or croak "setsockopt(SO_RCVTIMEO): $!";
    }

    if ($timeout_write) {
        my $seconds  = int( $timeout_write );
        my $useconds = int( 1_000_000 * ( $timeout_write - $seconds ) );
        my $timeout  = pack( 'l!l!', $seconds, $useconds );

        $instance->setsockopt( SOL_SOCKET, SO_SNDTIMEO, $timeout )
          or croak "setsockopt(SO_SNDTIMEO): $!";
    }

    return $instance;
}

sub clean {
    my ($self) = @_;
    $self->close;
    ${*$self}{__is_valid__} = 0;
}

sub wrapper {
    my $orig = shift;
    my $self = shift;

if ($ENV{DUMP_GETLINE}) {
    use Data::Dumper; print STDERR " >>>>>>>>>> IN GETLINE PLOP is " . $ENV{PLOP} . " " . Dumper({ %{*$self} });
#print STDERR " >>>>>>>>> IN WRAPPER VALID is : " . ${*$self}{__is_valid__} . "\n";
}

# If there is no __is_valid__ we should not abort.
#    ${*$self}{__is_valid__} == 0

    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    my $result = $orig->($self, @_);
    defined $result and return $result;

    clean($self);
    $! = ETIMEDOUT;
    return;
}

1;
