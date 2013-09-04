package IO::Socket::Timeout::Strategy::Alarm;

use strict;
use warnings;

use Class::Method::Modifiers qw(install_modifier);
use POSIX qw(ETIMEDOUT ECONNRESET);
use Time::HiRes qw(alarm);
use Config;
use Carp;


# ABSTRACT: proxy to read/write using Alarm as a timeout provider ( Not Safe: can clobber previous alarm )

sub apply_to_class {
    my ($class, $into, $timeout_read, $timeout_write) = @_;

    # from perldoc perlport
    # alarm:
    #  Emulated using timers that must be explicitly polled whenever
    #  Perl wants to dispatch "safe signals" and therefore cannot
    #  interrupt blocking system calls (Win32)

    $Config{osname} eq 'MSWin32'
      and croak "Alarm cannot interrupt blocking system calls in Win32!";

#    $timeout_read
#      and install_modifier($into, 'around', 'sysread', \&sysread_with_timeout);

    $timeout_read
      and install_modifier($into, 'around', 'print', \&print_with_timeout);

    $timeout_write
      and install_modifier($into, 'around', 'syswrite', \&syswrite_with_timeout);

}

sub apply_to_instance {
    my ($class, $instance, $into, $timeout_read, $timeout_write) = @_;
    ${*$instance}{__timeout_read__} = $timeout_read;
    ${*$instance}{__timeout_write__} = $timeout_write;
    ${*$instance}{__is_valid__} = 1;
    return $instance;
}

sub clean {
    my ($self) = @_;
    print STDERR " ------------------- CLEAN -------------- \n";
    $self->close;
    ${*$self}{__is_valid__} = 0;
}

# sub sysread_with_timeout {
#     my $orig = shift;
#     my $self = shift;

# print STDERR "in sysread_with_timeout";

#     ${*self}{__is_valid__} or $! = ECONNRESET, return;

#     my $buffer;
#     my $seconds = ${*self}{__timeout_read__};

#     my $result = eval {
#         local $SIG{'ALRM'} = sub { croak 'Timeout !' };
#         alarm($seconds);

#         my $data_read = $orig->($self, @_);

#         alarm(0);

#         $buffer = $_[0];    # NECESSARY, timeout does not map the alias @_ !!
#         $data_read;
#     };

#     if ($@) {
#         $self->clean();
#         $! = ETIMEDOUT;
#     }
#     else {
#         $_[0] = $buffer;
#     }

#     $result;
# }

sub print_with_timeout {
    my $orig = shift;
    my $self = shift;

    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    my $seconds = ${*self}{__timeout_write__};

    my $result = eval {
        local $SIG{'ALRM'} = sub { croak 'timeout while performing print' };
        alarm($seconds);

        my $data_read = $orig->($self, @_);

        alarm(0);

        $buffer = $_[0];    # NECESSARY, timeout does not map the alias @_ !!
        $data_read;
    };

    if ($@) {
        $self->clean();
        $! = ETIMEDOUT;
    }
    else {
        $_[0] = $buffer;
    }

    $result;
}

sub syswrite_with_timeout {
    my $self = shift;
    ${*self}{__is_valid__} or $! = ECONNRESET, return;

    my $seconds = $self->out_timeout;
    my $result  = eval {
        local $SIG{'ALRM'} = sub { croak 'Timeout !' };
        alarm($seconds);

        my $readed = $self->socket->syswrite(@_);

        alarm(0);

        $readed;
    };
    if ($@) {
        $self->clean();
        $! = ETIMEDOUT;    ## no critic (RequireLocalizedPunctuationVars)
    }

    $result;
}

1;

__END__

=head1 DESCRIPTION
  
  Internal class

