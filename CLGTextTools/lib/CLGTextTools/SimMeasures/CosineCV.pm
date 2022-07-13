package CLGTextTools::SimMeasures::CosineCV;

#twdoc
#
# Sim measure class which implements the cosine similarity for Context Vectors.
#
# ---
# EM Jul 2022
# 
#/twdoc
#

use strict;
use warnings;
use Carp;
use Log::Log4perl;
use CLGTextTools::Logging qw/confessLog cluckLog/;
use CLGTextTools::Commons qw/readTextFileLines arrayToHash/;

use Data::Dumper qw(Dumper);

our @ISA=qw/CLGTextTools::SimMeasures::Measure/;

# TODO: add funtionality for getting m x n matrice for cosine similarities and get min, max, medium and range from that.


#twdoc new($class, $params)
#
# see parent. Additional parameters:
#
#/twdoc
sub new {
    my ($class, $params) = @_;
    my $self = $class->SUPER::new($params, __PACKAGE__);
    bless($self, $class);
    return $self;
}



#twdoc compute($self, $doc1, $doc2)
#
# see parent.
#
#/twdoc
sub compute {
    my ($self, $doc1, $doc2) = @_;

    my ($obs, $cv1, $cv2);
    my $sumProd = 0;
    my ($normSum1, $normSum2) = (0,0);

	print Dumper \%$doc1;

    # get cosine similarity of 2 context vectors.
    while (($obs, $cv1) = each %$doc1) { # only common obs
        my $cv2 = $doc2->{$obs};
        $cv2 = 0 if (!defined($cv2)); 


    }

    while (($obs, $cv2) = each %$doc2) {
		if (!defined($doc1->{$obs})) {

		}
	}

    my ($n1, $n2)  = ( sqrt($normSum1), sqrt($normSum2) );
    $self->{logger}->debug("compute cosine: norm1=$n1; norm2=$n2; sumProd=$sumProd") if ($self->{logger});
    return 0 if ($n1*$n2 == 0);
    return $sumProd / ($n1 * $n2);

}




1;
