package Raisin::Request;

use strict;
use warnings;

use base 'Plack::Request';

sub new {
    my ($class, $app, $env) = @_;
    my $self = $class->SUPER::new($env);
    $self->{app} = $app;
    $self;
}

sub app { shift->{app} }

sub deserialize {
    my ($self, $data) = @_;

    my $serializer = do {
        if (my $c = Raisin::Util::detect_serializer($self->content_type)) {
            warn 'detected';
            Plack::Util::load_class('Raisin::Plugin::Format::' . uc($c));
        }
        elsif ($self->app->can('serializer')) {
            warn 'default';
            $self->app->serializer;
        }
    };

    if ($serializer) {
        $data = $serializer->deserialize($data);
    }

    $data;
}

sub declared_params { shift->{'raisin.params'} }

sub prepare_params {
    my ($self, $declared, $named) = @_;

    # Serialization / Deserialization
    my $params = do {
        if ($self->method =~ /POST|PUT/ && (my $content = $self->content)) {
            if ($self->content_type =~ m{application/x-www-form-urlencoded}imsx) {
                $self->body_parameters->mixed;
            }
            else {
                $self->deserialize($content);
            }
        }
        else {
            $self->query_parameters->mixed;
        }
    };

    foreach my $p (@$declared) {
        my $name = $p->name;

        $self->{'raisin.params'}{$name} = undef;

        # Route params has more precedence than query params
        my $value = $named->{$name} // $params->{$name};

        if (not $p->validate(\$value)) {
            $p->required ? return : next;
        }

        $value //= $p->default if defined $p->default;
        next if not defined($value);

        $self->{'raisin.params'}{$name} = $value;
    }

    1;
}

1;

__END__

=head1 NAME

Raisin::Request - Request class for Raisin.

=head1 SYNOPSIS

    Raisin::Request->new($self, $env);

=head1 DESCRIPTION

Extends L<Plack::Request>.

=head1 METHODS

=head3 app

=head3 declared_params

=head3 set_declared_params

=head3 set_named_params

=head3 populate_params

=cut
