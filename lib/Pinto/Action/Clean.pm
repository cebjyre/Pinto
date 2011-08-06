package Pinto::Action::Clean;

# ABSTRACT: An action to remove cruft from the repository

use Moose;

use File::Find;
use Path::Class;

extends 'Pinto::Action';

use namespace::autoclean;

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------

override execute => sub {
    my ($self) = @_;

    my $local      = $self->config()->local();
    my $search_dir = Path::Class::dir($local, qw(authors id));
    return 0 if not -e $search_dir;

    my @deleted = ();
    my $wanted = $self->_make_callback($search_dir, \@deleted);
    File::Find::find($wanted, $search_dir);
    return 0 if not @deleted;

    my $message = Pinto::Util::format_message('Deleted archives:', sort @deleted);
    $self->_set_message($message);
    return 1;
};

#------------------------------------------------------------------------------

sub _make_callback {
    my ($self, $search_dir, $deleted) = @_;

    return sub {

        if (Pinto::Util::is_source_control_file( $_ )) {
            $File::Find::prune = 1;
            return;
        }

        return if not -f $File::Find::name;

        my $physical_file = file($File::Find::name);
        my $index_file  = $physical_file->relative($search_dir)->as_foreign('Unix');
        return if $self->idxmgr()->master_index()->find( file => $index_file );

        $self->store->remove(file => $physical_file, prune => 1);
        push @{ $deleted }, $index_file;
    };
}

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable();

#------------------------------------------------------------------------------

1;

__END__
