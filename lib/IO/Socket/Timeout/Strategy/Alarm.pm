package IO::Socket::Timeout::Strategy::Alarm;

use Class::Method::Modifiers qw(install_modifier);
use POSIX qw(ETIMEDOUT ECONNRESET);
use Time::HiRes qw(alarm);
use Config;


# ABSTRACT: proxy to read/write using Alarm as a timeout provider ( Not Safe: can clobber previous alarm )

has socket      => ( is => 'ro', required => 1 );
has in_timeout  => ( is => 'ro', isa      => Num, default => sub {0.5} );
has out_timeout => ( is => 'ro', isa      => Num, default => sub {0.5} );
has is_valid    => ( is => 'rw', isa      => Bool, default => sub {1} );

sub apply_to {
    my ($class, $into, $timeout_read, $timeout_write) = @_;

    # from perldoc perlport
    # alarm:
    #  Emulated using timers that must be explicitly polled whenever
    #  Perl wants to dispatch "safe signals" and therefore cannot
    #  interrupt blocking system calls (Win32)

    $Config{osname} eq 'MSWin32'
      and croak "Alarm cannot interrupt blocking system calls in Win32!";

    install_modifier($into, 'around', sysread, \&sysread_with_timeout);

}

sub clean {
    $_[0]->close;
    $_[0]->{__is_valid__} = 0;
}

sub sysread_with_timeout {
    my $orig = shift;
    my $self = shift;

    $self->{__is_valid__} or $! = ECONNRESET, return;

    my $buffer;
    my $seconds = $self->in_timeout;

    my $result = eval {
        local $SIG{'ALRM'} = sub { croak 'Timeout !' };
        alarm($seconds);

        my $data_read = $orig->($self, @_);

        alarm(0);

        $buffer = $_[0];    # NECESSARY, timeout does not map the alias @_ !!
        $data_read;
    };

    if ($@) {
        $self->clean();
        $! = ETIMEDOUT;     ## no critic (RequireLocalizedPunctuationVars)
    }
    else {
        $_[0] = $buffer;
    }

    $result;
}

sub syswrite {
    my $self = shift;
    $self->is_valid or $! = ECONNRESET, return;    ## no critic (RequireLocalizedPunctuationVars)

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

