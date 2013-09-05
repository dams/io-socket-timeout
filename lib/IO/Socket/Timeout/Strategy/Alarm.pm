package IO::Socket::Timeout::Strategy::Alarm;

use strict;
use warnings;
use Time::HiRes;
use Time::Out qw(timeout);

use Class::Method::Modifiers qw(install_modifier);
use POSIX qw(ETIMEDOUT ECONNRESET);
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

    my @wrap_read_functions = qw(getc print printf getline getlines);
    my @wrap_read_functions_with_buffer = qw(recv sysread read);
    my @wrap_write_functions = qw( say truncate);
    my @wrap_write_functions_with_buffer = qw(send syswrite write);

    if ($timeout_read) {
        install_modifier($into, 'around', $_, \&read_wrapper)
          foreach @wrap_read_functions;
        install_modifier($into, 'around', $_, \&read_wrapper_with_buffer)
          foreach @wrap_read_functions_with_buffer;
    }
#    $timeout_write
#      and install_modifier($into, 'around', 'print', \&print_with_timeout);

#    $timeout_write
#      and install_modifier($into, 'around', 'syswrite', \&syswrite_with_timeout);



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
    $self->close;
    ${*$self}{__is_valid__} = 0;
}

sub read_wrapper_with_buffer {
     my $orig = shift;
     my $self = shift;

 print STDERR "---------- in wrapper_with_timeout buffer\n";

     ${*$self}{__is_valid__} or $! = ECONNRESET, return;

     my $buffer;
     my $seconds = ${*$self}{__timeout_read__};

     my $buffer = $_[0];
     my $result = timeout $seconds, @_ => sub {
         my $data_read = $orig->($self, @_);
         $buffer = $_[0]; # timeout does not map the alias @_, so we need to save it here
         $data_read;
     };
    $@ or $_[0] = $buffer, return $result;

    clean($self);
    $! = ETIMEDOUT;
    return;
}

sub read_wrapper {
    my $orig = shift;
    my $self = shift;


    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    my $seconds = ${*$self}{__timeout_read__};

    my $result = timeout $seconds, @_ => sub { $orig->($self, @_) };
    $@ or return $result;

    clean($self);
    $! = ETIMEDOUT;
    return;
}

sub write_wrapper {
    my $orig = shift;
    my $self = shift;

    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    my $seconds = ${*$self}{__timeout_write__};

    my $result = timeout $seconds, @_ => sub { $orig->($self, @_) };
    $@ or return $result;

    clean($self);
    $! = ETIMEDOUT;
    return;
}

sub syswrite_with_timeout {
    my $self = shift;
    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    my $seconds = $self->out_timeout;
    my $result  = eval {
        local $SIG{'ALRM'} = sub { croak 'Timeout !' };
        alarm($seconds);

        my $readed = $self->socket->syswrite(@_);

        alarm(0);

        $readed;
    };
    if ($@) {
        clean($self);
        $! = ETIMEDOUT;    ## no critic (RequireLocalizedPunctuationVars)
    }

    $result;
}

1;

__END__

=head1 DESCRIPTION
  
  Internal class

