  package Term::Report;

  $|++;
  require 5.6.0;
  use Number::Format;
  use Term::StatusBar;
  use Term::ANSIScreen qw(:cursor :color :constants);
  $Term::ANSIScreen::AUTORESET = 1;
  our $CR;
  our $VERSION = do { my @r=(q$Revision: 1.8 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };

  sub new {
      my $class = shift;
      my (%params) = @_;

      my $self = bless {
		curText => '',
		prevText => '',
		currentRow => $params{startRow} || 1,
		startRow => $params{startRow} || 1,
		startCol => $params{startCol} || 1,
		numFormat => $params{numFormat},
		statusBar => $params{statusBar},
      }, ref $class || $class;


  ################################
  # Do we want to format numbers?
  ################################

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


  ################################
  # Do we have a Term::StatusBar? 
  ################################

      if ($self->{statusBar} eq '1'){
          $self->{statusBar} = Term::StatusBar->new;
      }
      elsif (ref $self->{statusBar} eq 'ARRAY'){
          $self->{statusBar} = Term::StatusBar->new(@{$self->{statusBar}});
      }


  ###############################################
  # Unload modules we don't need. Commented out 
  # since Perl 5.6.0 users have problems.
  ###############################################

      if (!$self->{numFormat}){
          #no Number::Format;
      }

      if (!$self->{statusBar}){
          #no Term::StatusBar;
      }


  ###################################################
  # If Term::StatusBar is inside, we will override 
  # it's SIG{INT}. If not wrapped and called after 
  # we are created, SIG{INT} will not 'behave' and 
  # will drop the cursor on the 2nd row rather than 
  # 2 rows down from current cursor position.
  ###################################################

      $CR = \$self->{currentRow};
      $SIG{INT} = \&{__PACKAGE__."::sigint"};

      return $self;
  }


  sub DESTROY { sigint(); }


#############################################
# Just in case this isn't done in caller. We
# need to be able to reset the display.
#############################################

  sub sigint {
      RESET;
      locate $$CR, 1;
      print "\n\n";
      exit;
  }



####################################
# Used to get/set object variables.
####################################

  sub AUTOLOAD {
      my $self = shift;
      (my $method = $AUTOLOAD) =~ s/.*:://;
      my $val = shift;

      if (exists $self->{$method}){
          if (defined $val){
              $self->{$method} = $val;
          }
          else{
              return $self->{$method};
          }
      }
  }


########################################
# Prints text to screen based on manual 
# cursor positioning.
########################################

  sub finePrint {
      my $self = shift;
      my ($row, $col, @text) = @_;
      my $text = join('', @text);

      locate $row, $col;

      if ($self->{numFormat}){
          $text =~ s/(\d+)/$self->{numFormat}->format_number($1)/sge;
      }

      print $text;
  }


#########################################
# Prints text to screen based on current
# cursor positioning.
#########################################

  sub printLine {
      my $self = shift;
      my $text = join('', @_);

      if ($self->{numFormat}){
          $text =~ s/(\d+)/$self->{numFormat}->format_number($1)/sge;
      }

      if (!$self->{prevText}){
          locate $self->{currentRow}, $self->{startCol};
          $self->{currentRow} += ($text =~ s/\n/\n/g);
          $self->{prevText} = $text;
      }
      else{
          if ($self->{prevText} !~ /\n/){
              if ($text =~ /^\n/){
                  $self->{currentRow} += ($text =~ s/^\n//g);
                  locate $self->{currentRow}, $self->{startCol};
                  $self->{prevText} = $text;
              }
              else{
                  locate $self->{currentRow}, length($self->{prevText});
                  $self->{prevText} .= $text;
              }
          }
          else{
              $self->{currentRow} += ($self->{prevText} =~ s/\n/\n/g);
              $self->{currentRow} += ($text =~ s/^\n//g);
              locate $self->{currentRow}, $self->{startCol};
              $self->{prevText} = $text;
          }
      }

      $self->{curText} = $text;
      print $text;
  }


#########################
# Returns length of text
#########################

  sub lineLength {
      my $self = shift;
      length $self->{shift()};
  }


###########################
# Prints out a bar report. 
###########################

  sub printBarReport {
      my $self = shift;
      my ($header, $config) = @_;

      return if !defined $self->{statusBar};
      $self->printLine($header);

      for my $k (keys %{$config}){
          my $num = int(($self->{statusBar}->{scale}/$self->{statusBar}->{totalItems}) * $config->{$k});

          if ($num < length($config->{$k})){
              $num = length($config->{$k});
          }

          $self->printLine($k, WHITE ON BLACK REVERSE, $config->{$k}, " "x($num), "\n");
      }
  }


1;
__END__

=pod

=head1 NAME

Term::Report - Easy way to create dynamic 'reports' from within scripts.

=head1 SYNOPSIS

    use Term::Report;

    my $items = 10000;
    my $report = Term::Report->new(
            startRow => 4,
            numFormat => 1,
            statusBar => [label => 'Report Status: ', subText => 'Locating widgets', subTextAlign => 'center'],
    );

    my $status = $report->{statusBar};  ## Alias this cause I'm lazy
    $status->setItems($items);
    $status->start;

    $report->printLine("Total widgets I found so far... ");
    my $discard = 0;

    for (1..$items){
        $report->finePrint($report->currentRow(), $report->lineLength('curText')+1, $_);

        if (!($_%(rand(1000)+1000))){
            $discard++;
            $status->subText("Discarding bad widget");
            for my $t (1..1000000){ ## Fake like we are doing something
                $status->subText($status->subText() . "..") if !($t%900000);
            }
        }
        else{
            $status->subText("Locating widgets");
        }

        $status->update;
    }

    $report->printLine("\n  $discard widgets were discarded\n");

    $status->reset;
    $status->setItems($items-$discard);
    $status->subText('Processing widgets');
    $status->start;

    $report->printLine("\nInventorying widgets... ");

    for (1..($items-$discard)){
        $report->finePrint($report->currentRow(), $report->lineLength('curText')+1, $_);
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
up more readable. All output is sent to STDOUT.

=head1 METHODS

=head2 new(parameters)

	startRow  - This indicates which row to start at. Default is 1.
	startCol  - This indicates which column to start at. Default is 1.
	numFormat - This indicates if you want to use Number::Format. Default is undef.
	statusBar - This indicats if you want to use Term::StatusBar. Default is undef.


numFormat and statusBar can be passed in 2 different ways.

The first way is as a simple flag:
	numFormat => 1

Or as an array reference with parameters for a Number::Format object:
	numFormat => [-MON_DECIMAL_POINT => ',', -INT_CURR_SYMBOL => '']

statusBar behaves the same way except takes parameters appropriate for Term::StatusBar.

=head2 finePrint($row, $col, @text)

This gives more control over where to place text.

=head2 printLine(@text)

This places text after the last known text has been placed. It tries very hard to 
"Do The Right Thing", but I am certain there are more 'bugs' in it.

=head2 lineLength('m')

Returns length($obj->{m})

=head1 AUTHOR

Shay Harding E<lt>sharding@ccbill.comE<gt>

=head1 COPYRIGHT

This library is free software;
you may redistribute and/or modify it under the same
terms as Perl itself.

=head1 SEE ALSO

L<Term::StatusBar>, L<Number::Format>, L<Term::ANSIScreen>

=cut

