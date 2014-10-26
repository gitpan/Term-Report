package Term::Report;
no warnings 'portable';

$|++;
require 5.6.0;
use Number::Format qw(format_number);
use Term::StatusBar;
our ($CR, $FH);
our $VERSION = do { my @r=(q$Revision: 1.3 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };


sub new {
  my ($class, %params) = @_;

  my $self = bless {
      curText     => undef,
      prevText    => undef,
      currentRow  => $params{startRow} || 1,
      startRow    => $params{startRow} || 1,
      startCol    => $params{startCol} || 1,
      numFormat   => $params{numFormat},
      statusBar   => $params{statusBar},
      SP          => {},   ## Save point list
      noPrint     => 0,    ## Delays printing of text
      fh          => $params{fh}       || *STDOUT,
  }, ref $class || $class;

  $FH = $self->{fh};

  ## Do we want to format numbers?
  if ($self->{numFormat} eq '1'){
    $self->{numFormat} = Number::Format->new(
                    -MON_DECIMAL_POINT => ',',
                    -INT_CURR_SYMBOL => '',
                    -DECIMAL_DIGITS => 0,
    );
  }
  elsif (ref $self->{numFormat} eq 'ARRAY'){
    $self->{numFormat} = Number::Format->new(@{$self->{numFormat}});
  }

  ## Do we have a Term::StatusBar? 
  if ($self->{statusBar} eq '1'){
    $self->{statusBar} = Term::StatusBar->new(fh=>$self->{fh});
  }
  elsif (ref $self->{statusBar} eq 'ARRAY'){
    push @{$self->{statusBar}}, ("fh", $self->{fh});
    $self->{statusBar} = Term::StatusBar->new(@{$self->{statusBar}});
  }

  ## If Term::StatusBar is inside, we will override 
  ## it's SIG{INT}. If not wrapped and called after 
  ## we are created, SIG{INT} will not 'behave' and 
  ## will drop the cursor on the 2nd row rather than 
  ## 2 rows down from current cursor position.
  $CR = \$self->{currentRow};
  $SIG{INT} = \&{__PACKAGE__."::sigint"};

  if (!defined $params{cls} || $params{cls}){ print $FH "\e[2J"; }

  return $self;
}


sub DESTROY { sigint(); }


##
## Just in case this isn't done in caller. We
## need to be able to reset the display.
##
sub sigint {
  print $FH "\e[$$CR;1H\e[0m\n\n";
  exit;
}


##
## Used to get/set object variables.
##
sub AUTOLOAD {
  my ($self, $val) = @_;
  (my $method = $AUTOLOAD) =~ s/.*:://;

  if (exists $self->{$method}){
    if (defined $val){
      $self->{$method} = $val;
    }
    else{
      return $self->{$method};
    }
  }
}


##
## Prints text to screen based on manual 
## cursor positioning.
##
sub finePrint {
  my ($self, $row, $col, @text) = @_;
  my $text = join('', @text);

  ## Passed a save point label
  if ($row !~ /^\d+$/){
    my $label = $row;
    $row  = $self->{SP}->{$label}->row;

    if (my $t = $self->{SP}->{$label}->text){
      ## We only want to reset once to avoid 
      ## flickering as much as possible
      if (!$self->{SP}->{$label}->reset){
        ## Clear current row to replace text
        print $FH "\e[$row;1H\e[K";
        $text = $t.$text;
        $self->{SP}->{$label}->reset(1);
        $col = $self->{SP}->{$label}->col;
      }
      else{
        $col = $self->{SP}->{$label}->textLen+1;
      }
    }
    else{
      $col  = $self->{SP}->{$label}->textLen;
    }
  }

  print $FH "\e[$row;${col}H";

  if ($self->{numFormat}){
    $text =~ s/(\d+)/$self->{numFormat}->format_number($1)/sge;
  }

  print $FH $text;
}


##
## Prints text to screen based on current
## cursor positioning.
##
sub printLine {
  my $self = shift;
  my $text = join('', @_);

  if ($self->{numFormat}){
    $text =~ s/(\d+)/$self->{numFormat}->format_number($1)/sge;
  }

  if (!$self->{prevText}){
    $self->adjustCurRow(\$text);
    print $FH "\e[$self->{currentRow};$self->{startCol}H";
    $self->{prevText} = $text;
  }
  else{
    if ($self->{prevText} !~ /\n/){
      if ($text =~ /^\n/){
        $self->adjustCurRow(\$text);
        $self->{prevText} = $text;
        print $FH "\e[$self->{currentRow};$self->{startCol}H";
      }
      else{
        $self->{prevText} .= $text;
        print $FH "\e[$self->{currentRow};", (length($self->{prevText})), "H";
      }
    }
    else{
      $self->{currentRow} += ($self->{prevText} =~ s/\n/\n/g);
      $self->adjustCurRow(\$text);
      $self->{prevText} = $text;
      print $FH "\e[$self->{currentRow};$self->{startCol}H";
    }
  }

  $self->{curText} = $text;
  print $FH $text if !$self->{noPrint};
}


##
## Keeps track of where current row
## should be for line placements
##
sub adjustCurRow{
   my ($self, $text) = @_;
   my $len = length($$text);
   $$text =~ s/^\n+//;
   $self->{currentRow} += ($len - length($$text));
}

##
## Returns length of text
##
sub lineLength {
  length shift()->{shift()};
}


##
## Prints out a bar report. 
##
sub printBarReport {
  my ($self, $header, $config) = @_;

  return if !defined $self->{statusBar};
  $self->printLine($header);

  for my $k (keys %{$config}){
    my $num = int(($self->{statusBar}->{scale}/$self->{statusBar}->{totalItems}) * $config->{$k});

    if ($num < length($config->{$k})){
      $num = length($config->{$k});
    }

    $self->printLine($k, "\e[7;37m\e[40m", $config->{$k}, " "x($num), "\e[0m\n");
  }
}


##
## Stores information on screen locations for 
## easy referencing later in code
##
sub savePoint {
  my ($self, $label, $text, $print) = @_;
  return if !defined $label;

  if (defined $text){
    $self->{noPrint} = !$print;
    $self->printLine($text);
    $self->{noPrint} = 0;
  }

  $self->{SP}->{$label} = Term::Report::SP->new({
        label   => $label,
        text    => $self->{curText},
        textLen => $self->lineLength('curText'),
        row     => $self->currentRow(),
        col     => $self->{startCol},
  });
}


## Internal package to provide easy access
## to the report's save points
package Term::Report::SP;
*{__PACKAGE__."::AUTOLOAD"} = \&Term::Report::AUTOLOAD;

sub new {
  bless {
      label   => $_[1]->{label}   || undef,
      text    => $_[1]->{text}    || undef,
      textLen => $_[1]->{textLen} || undef,
      row     => $_[1]->{row}     || undef,
      col     => $_[1]->{col},
      reset   => 0,
  }, $_[0];
}


1;
__END__
=pod
=head1 NAME

Term::Report - Easy way to create dynamic 'reports' from within scripts.

=head1 SYNOPSIS

   use Term::Report;
   use Time::HiRes qw(usleep);

   my $items = 100;
   my $report = Term::Report->new(
            startRow => 4,
            numFormat => 1,
            statusBar => [
               label => 'Widget Analysis: ',
               subText => 'Locating widgets',
               subTextAlign => 'center',
               showTime=>1
            ],
   );

   my $status = $report->{statusBar};
   $status->setItems($items);
   $status->start;

   $report->savePoint('total', "Total widgets: ", 1);
   $report->savePoint('discarded', "\n  Widgets discarded: ", 1);

   for (1..$items){
      $report->finePrint('total', 0, $_);

      if (!($_%int((rand(10)+rand(10)+1)))){
         $report->finePrint('discarded', 0, ++$discard);
         $status->subText("Discarding bad widget");
      }
      else{
         $status->subText("Locating widgets");
      }

      usleep(75000);
      $status->update;
   }

   $status->reset({reverse=>1, subText=>'Processing widgets', setItems=>($items-$discard), start=>1});
   $report->savePoint('inventory', "\n\nInventorying widgets... ", 1);

   for (1..($items-$discard)){
      $report->finePrint('inventory', 0, $_);
      $status->update;
   }

   $report->printBarReport(
      "\n\n\n\n    Summary for widgets: \n\n",
      {
            "       Total:        " => $items,
            "       Good Widgets: " => $items-$discard,
            "       Bad Widgets:  " => $discard,
      }
   );

=head1 DESCRIPTION

Term::Report can be used to generate nicely formatted dynamic output. It can 
also use Term::StatusBar to show progress and Number::Format so numbers show 
up more readable. All output is sent to STDOUT by default.

The current release may not be compatible with previous code. Many changes were 
made with regards to how output could be formatted.

=head1 METHODS

=head2 new(parameters)

   cls       - This clears the screen. Default is 1.
   startRow  - This indicates which row to start at. Default is 1.
   startCol  - This indicates which column to start at. Default is 1.
   numFormat - This indicates if you want to use Number::Format. Default is undef.
   statusBar - This indicates if you want to use Term::StatusBar. Default is undef.
   fh        - User-defined file handle. This is passed on to Term::StatusBar. Default is STDOUT.

numFormat and statusBar can be passed in 2 different ways.

The first way is as a simple flag:
    numFormat => 1

Or as an array reference with parameters for a Number::Format object:
    numFormat => [-MON_DECIMAL_POINT => ',', -INT_CURR_SYMBOL => '']

statusBar behaves the same way except takes parameters appropriate for Term::StatusBar.

=head2 finePrint($row, $col, @text)

This gives more control over where to place text. With the introduction of 'save points', 
$row may be either a number, indicating a row, or a savepoint label, which may not be 
all numbers or it will be interpreted as a row.

=head2 printLine(@text)

This places text after the last known text has been placed. It tries very hard to 
"Do The Right Thing", but I am certain there are more 'bugs' in it.

=head2 lineLength('m')

Returns length($obj->{m}). This function shouldn't really be called as it has 
little purpose outside the module.

=head2 _adjustCurRow($text)

Internal function printLine() uses to try and place text properly.

=head2 printBarReport($header, $config)

Works in conjunction with Term::StatusBar to print a summary of data 
it processed.

=head2 savePoint($label, $text, $print)

Allows the referencing of a screen position with a text label. This calls 
printLine() and remembers the position it was placed in, along with the 
text it represents. $print is a flag indicating whether to immediately 
print the $text, or to delay it.

=head1 CHANGES

   2003-05-06
      Added "no warnings 'portable'" so Perl 5.8 would be happy.
      Added ability to send in a file handle to print to.

   2003-01-27
      Removed the dependency for Term::ANSIScreen.
      Added savePoint() method for easy referncing of screen locations.
      Adjusted finePrint() to work with savePoint().
      Added 'cls' flag to constructor to clear the screen.
      Cleaned up code a bit with minor optimizations.
      Reduced screen flicker by quite a bit.

=head1 AUTHOR

Shay Harding E<lt>sharding@ccbill.comE<gt>

=head1 COPYRIGHT

This library is free software;
you may redistribute and/or modify it under the same
terms as Perl itself.

=head1 SEE ALSO

L<Term::StatusBar>, L<Number::Format>

=cut

