package RevBank::Cart;
use v5.36;

use Carp ();
use List::Util ();
use RevBank::Global;
use RevBank::Accounts;
use RevBank::FileIO;
use RevBank::Cart::Entry;

{
    package RevBank::Cart::CheckoutProhibited;
    sub new($class, $reason) { return bless \$reason, $class; }
    sub reason($self) { return $$self; }
}

sub new($class) {
    return bless { entries => [] }, $class;
}

sub add_entry($self, $entry) {
    RevBank::Plugins::call_hooks("add_entry", $self, $entry);

    push @{ $self->{entries} }, $entry;
    $self->{changed}++;
    $self->select($entry);

    RevBank::Plugins::call_hooks("added_entry", $self, $entry);

    return $entry;
}

sub add($self, $amount, $description, $data = {}) {
    ref $data or Carp::croak "Non-hash data argument";

    return $self->add_entry(RevBank::Cart::Entry->new($amount, $description, $data));
}

sub select($self, $entry) {
    return $self->{selected_entry} = $entry;
}

sub selected($self) {
    return undef if not @{ $self->{entries} };

    for my $entry (@{ $self->{entries} }) {
        return $entry if $entry == $self->{selected_entry};
    }

    return $self->select( $self->{entries}->[-1] );
}

sub delete($self, $entry) {
    my $entries = $self->{entries};

    my $oldnum = @$entries;
    @$entries = grep $_ != $entry, @$entries;
    $self->{changed}++;

    return $oldnum - @$entries;
}

sub empty($self) {
    %$self = (entries => [], changed => 1);
}

sub display($self, $prefix = "") {
    say "$prefix$_" for map $_->as_printable, @{ $self->{entries} };
}

sub size($self) {
    return scalar @{ $self->{entries} };
}

sub prohibit_checkout($self, $bool, $reason) {
    if ($bool) {
        $self->{prohibited} = $reason;
    } else {
        delete $self->{prohibited};
    }
}

sub deltas($self, $account) {
    my %deltas = ($account => RevBank::Amount->new(0));

    for my $entry (@{ $self->{entries} }) {
        $deltas{$_->{account} // $account} += $_->{amount} * $entry->quantity
            for $entry, $entry->contras;
    }

    return \%deltas;
}


sub checkout($self, $account) {
    if ($self->{prohibited}) {
        die RevBank::Cart::CheckoutProhibited->new(
            "Cannot complete transaction: $self->{prohibited}"
        );
    }

    if ($self->entries('refuse_checkout')) {
        $self->display;
        die "Refusing to finalize deficient transaction";
    }

    $account = RevBank::Accounts::assert_account($account);

    my $entries = $self->{entries};

    for my $entry (@$entries) {
        $entry->sanity_check;
        $entry->account($account);
    }

    RevBank::FileIO::with_lock {
        my $fn = "nextid";

        my $transaction_id = RevBank::FileIO::slurp($fn);
        chomp $transaction_id;

        eval {
            RevBank::Plugins::call_hooks("checkout_prepare", $self, $account, $transaction_id)
            or die "Refusing to finalize after failed checkout_prepare";
        };
        if ($@ and $@ isa RevBank::Exception::AbortCheckoutRecoverably) {
            $self->{changed}++;  # force redisplay
            $_->account(undef) for @$entries;
            die RevBank::Exception::RejectInput->new($@->message, 1);
        } elsif ($@) {
            die $@;
        }

        # checkout_prepare could have added or changed entries
        for my $entry (@$entries) {
            $entry->sanity_check;
            $entry->account($account) if not $entry->account;
        }

        RevBank::FileIO::spurt($fn, ++(my $next_id = $transaction_id));

        RevBank::Plugins::call_hooks("checkout", $self, $account, $transaction_id);

        my $deltas = $self->deltas($account);

        for my $account (reverse sort keys %$deltas) {
            # The reverse sort is a lazy way to make the "-" accounts come last,
            # which looks nicer with the "cash" plugin.
            RevBank::Accounts::update($account, $deltas->{$account}, $transaction_id)
                if $deltas->{$account} != 0;
        }

        RevBank::Plugins::call_hooks("checkout_done", $self, $account, $transaction_id);

        sleep 1 if $RevBank::Shell::interactive;  # look busy

        $self->empty;
    };
}

sub entries($self, $attribute = undef) {
    my @entries = @{ $self->{entries} };
    return grep $_->has_attribute($attribute), @entries if defined $attribute;
    return @entries;
}

sub changed($self, $keep = 0) {
    my $changed = 0;
    for my $entry ($self->entries('changed')) {
        $entry->attribute('changed', undef) unless $keep;
        $changed = 1;
    }
    $changed = 1 if $self->{changed};
    delete $self->{changed} unless $keep;

    return $changed;
}

sub sum($self) {
    return List::Util::sum(map $_->{amount} * $_->quantity, @{ $self->{entries} });
}

1;
