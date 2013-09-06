package IO::Socket::Timeout::Strategy::Select;

use strict;
use warnings;
use Time::HiRes;
use IO::Select;

use Class::Method::Modifiers qw(install_modifier);
use POSIX qw(ETIMEDOUT ECONNRESET);
use Config;
use Carp;

use base qw(IO::Socket::Timeout::Strategy);

# ABSTRACT: proxy to read/write using IO::Select as a timeout provider

sub apply_to_class {
    my ($class, $into, $timeout_read, $timeout_write) = @_;

    $class->SUPER::apply_to_class(@_);

    my @wrap_read_functions = qw(getc getline getlines);
    my @wrap_read_functions_with_buffer = qw(recv sysread read);
    my @wrap_write_functions = qw( ungetc print printf say truncate);
    my @wrap_write_functions_with_buffer = qw(send syswrite write);

    if ($timeout_read) {
        install_modifier($into, 'around', $_, \&read_wrapper)
          foreach @wrap_read_functions, @wrap_read_functions_with_buffer;
    }

    if ($timeout_write) {
        install_modifier($into, 'around', $_, \&write_wrapper)
          foreach @wrap_write_functions, @wrap_write_functions_with_buffer;
    }
}

sub apply_to_instance {
    my ($class, $instance, $into, $timeout_read, $timeout_write) = @_;
    ${*$instance}{__timeout_read__} = $timeout_read;
    ${*$instance}{__timeout_write__} = $timeout_write;
    ${*$instance}{__is_valid__} = 1;
    ${*$instance}{__select__} = IO::Select->new;
    ${*$instance}{__select__}->add($instance);
    return $instance;
}

sub clean {
    my ($self) = @_;
    $self->close;
    ${*$self}{__select__}->remove( $_[0] );
    ${*$self}{__is_valid__} = 0;
}

sub read_wrapper {
    my $orig = shift;
    my $self = shift;

    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    ${*$self}{__select__}->can_read(${*$self}{__timeout_read__})
      and return $orig->($self, @_);

    clean($self);
    $! = ETIMEDOUT;
    return;
}

sub write_wrapper {
    my $orig = shift;
    my $self = shift;

    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    ${*$self}{__select__}->can_write(${*$self}{__timeout_write__})
      and return $orig->($self, @_);

    clean($self);
    $! = ETIMEDOUT;
    return;
}

1;
