#!/usr/bin/env perl

$| = 1;

use strict;
use warnings;
use autodie;
use feature 'say';
use Cwd qw'cwd realpath';
use Data::Dump 'dump';
use File::Basename qw'basename fileparse';
use FindBin '$Bin';
use File::Path 'make_path';
use File::Find::Rule;
use File::Spec::Functions;
use Getopt::Long;
use List::Util 'sum';
use Pod::Usage;
use Readonly;
use Template;

our $META_PCT_UNIQ = 80;
our $DEBUG = 0;

main();

# --------------------------------------------------
sub main {
    my $out_dir             = cwd();
    my $metadir             = '';
    my $euc_dist_per        = 0.10;
    my $max_sample_distance = 1000;
    my $seq_matrix          = '';
    my $verbose             = 0;
    my $num_scans           = 100000;
    my ($help, $man_page);

    GetOptions(
        'o|out-dir=s'    => \$out_dir,
        'm|metadir=s'    => \$metadir,
        'e|eucdistper=s' => \$euc_dist_per,
        'd|sampledist=s' => \$max_sample_distance,
        's|seq-matrix=s' => \$seq_matrix,
        'v|verbose'      => \$DEBUG,
        'n|num-scans:i'  => \$num_scans,
        'help'           => \$help,
        'man'            => \$man_page
    ) or pod2usage(2);

    if ($help || $man_page) {
        pod2usage({
            -exitval => 0,
            -verbose => $man_page ? 2 : 1
        });
    }

    unless ($seq_matrix) {
        pod2usage('No sequence matrix');
    }

    unless (-e $seq_matrix) {
        pod2usage("Bad matrix file ($seq_matrix)");
    }

    unless ($metadir) {
        pod2usage('No metadata directory specified');
    }

    unless (-d $metadir) {
        pod2usage("Metadir ($metadir) is not a directory");
    }

    my @metafiles 
        = File::Find::Rule->file()->name(qr/\.(d|c|ll)$/)->in($metadir)
        or die "Found no d/c/ll files in ($metadir)\n";

    unless (-d $out_dir) {
        make_path($out_dir);
    }

    # step 1 create the metadata tables for the analysis
    # the input is in the format -> id<tab>metadata_value (with a header)
    # input file either need to be:
    # (1) ".ll" for lat_lon
    # (2) ".c" for continous data
    # (3) ".d" for decrete
    # this is how we tell which subroutine to use for creating the
    # metadata matrix files for input into SNA

    # first we need to get a list of the sample ids
    my @samples;
    open my $SM, '<', $seq_matrix;
    while (<$SM>) {
        chomp $_;
        my @fields = split(/\t/, $_);
        my $sample = shift @fields;
        push @samples, $sample;
    }

    shift @samples; # remove the first line with no sample name

    my @meta = ();
    for my $file (@metafiles) {
        my $matrix_file = '';

        if ($file =~ /\.d$/) {
            $matrix_file = discrete_metadata_matrix($file, $out_dir);
        }
        elsif ($file =~ /\.c$/) {
            $matrix_file = continuous_metadata_matrix(
                $file, $euc_dist_per, $out_dir
            );
        }
        elsif ($file =~ /\.ll$/) {
            $matrix_file = distance_metadata_matrix(
                $file, $max_sample_distance, $out_dir
            );
        }
    
        if ($matrix_file) {
            push @meta, basename($matrix_file);
        }
    }

    # now we need to run the SNA analysis
    # be sure that `module load R` has already been run in the
    # shell script that runs this perl script on the 
    # compute node
    my $gbme_r = catfile($out_dir, 'gbme.R');
    my $sna_r  = catfile($out_dir, 'sna.R');
    my $plot_r = catfile($out_dir, 'plot.R');

    open my $gbme_fh, '>', $gbme_r;
    open my $sna_fh,  '>', $sna_r;
    open my $plot_fh, '>', $plot_r;

    my $t         = Template->new;
    my $sna_tmpl  = template_sna();
    my $plot_tmpl = template_plot();

    print $gbme_fh template_gbme();

    $t->process(
        \$sna_tmpl, 
        { 
            gbme       => $gbme_r,
            out_dir    => $out_dir,
            seq_matrix => basename($seq_matrix),
            num_scans  => $num_scans,
            meta       => \@meta,
        }, 
        $sna_fh
    ) or die $t->error;

    $t->process(
        \$plot_tmpl, 
        { 
            gbme    => $gbme_r,
            out_dir => $out_dir,
            samples => \@samples,
        }, 
        $plot_fh
    ) or die $t->error;

    close $gbme_fh;
    close $sna_fh;
    close $plot_fh;

    chdir($out_dir);
    for my $script ($sna_r, $plot_r) { 
        say "Executing '$script'";
        my $ret = system("R CMD BATCH --slave $script");
        if ($ret != 0) {
            warn "Error: ", $!;
        }
    }
}

# --------------------------------------------------
sub template_gbme {
    return <<'EOF'
###################################################################
#
# R source code providing generalized bilinear mixed effects modeling
# for social network data. For more information on the model fitting 
# procedure, see 
# "Bilinear Mixed-Effects Models for Dyadic Data" (Hoff 2003)
# http://www.stat.washington.edu/www/research/reports/2003/tr430.pdf
#
# This research was supported by ONR grant N00014-02-1-1011 
#
# Copyright (C) 2003 Peter D. Hoff
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, 
# Boston, MA  02111-1307, USA.
#
##################################################################

###Last modification : 2/22/04

###Preconditions of the main function "gbme"

##objects with no defaults
#Y : a square matrix (n*n)

##objects with defaults
#Xd : an n*n*rd array representing dyad-specific predictors
#Xs : an n*rs matrix of sender-specific predictors
#Xr : an n*rr matrix of receiver-specific predictors

# fam : "gaussian" "binomial", or "poisson"
# if fam="binomial" then an (n*n) matrix N of trials is needed
#
# pi.Sab = (s2a0,sab0,s2b0,v0) : parameters of inverse wishart dist
# pi.s2u = vector of length 2: parameters of an inv-gamma distribution
# pi.s2v = vector of length 2: parameters of an inv-gamma distribution
# pi.s2z = k*2 matrix : parameters of k inv-gamma distributions
#
# pim.bd  : vector of length rd, the prior mean for beta.d
# piS.bd  : a rd*rd pos def matrix, the prior covariance for beta.d
#
# pim.b0sr : vector of length 1+rs+rr, prior mean for (beta0,beta.s,beta.r)
# piS.b0sr  : a (1+rs+rr)*(1+rs+rr) pos def matrix, 
#             the prior variance for (beta0,beta.s,beta.r)

# k     : dimension of latent space
# directed : T or F. Is the data directed or undirected? If set to F, 
#                    estimation proceeds assuming Y[i,j]==Y[j,i], 
#                    and any supplied value of Xr is not used 
#                    also, only s2a0 and v0 in pi.Sab need be supplied, 
#                    and pi.s2v is not used. rr is zero, so pim.b0sr is 
#                    length 1+rs 

# starting values
# beta.d   #a vector of length rd
# beta.u   #a vector of length 1+rs+rr
# s        #a vector of length n
# r        #a vector of length n 
# z        #an n*k matrix

###the main  function
gbme<-function(
 #data 
 Y,  
 Xd=array(dim=c(n,n,0)),
 Xs=matrix(nrow=dim(Y)[1],ncol=0),
 Xr=matrix(nrow=dim(Y)[1],ncol=0),  

 #model specification
 fam="gaussian",         
 N=NULL, 
 k=0,
 directed=T, 

#compute starting values and emp Bayes for priors?
 estart=T, 
 
#priors  - provide if estart=F
 pi.Sab=NULL,
 pi.s2u=NULL,
 pi.s2v=NULL,
 pi.s2z=NULL,
 pim.bd=NULL,
 piS.bd=NULL,
 pim.b0sr=NULL,
 piS.b0sr=NULL,
 
 #starting values - provide if estart=F 
 beta.d=NULL,
 beta.u=NULL,
 s=NULL,
 r=NULL,
 z=NULL,

 #random seed, 
 seed=0,

 #details of output
 NS=100000,         #number of scans of mcmc to run
 odens=100,         #output density
 owrite=T,          #write output to a file? 
 ofilename="OUT",   #name of output file 
 oround=3,          #rounding of output
 zwrite=(k>0),      #write z to  file 
 zfilename="Z",     #outfile for z 
 sdigz=3,           #rounding for z
 awrite=T,bwrite=T,
 afilename="A",
 bfilename="B"
	       )
{

###set seed
set.seed(seed)
                                                                                


###dimensions of everything
n<<-dim(Y)[1]
rd<<-dim(Xd)[3]
rs<<-dim(Xs)[2]
rr<<-dim(Xr)[2]   
diag(Y)<<-rep(0,n)
###

###column names for output file
if(directed==T) {
cnames<-c("k","scan","ll",paste("bd",seq(1,rd,length=rd),sep="")[0:rd],"b0",
                          paste("bs",seq(1,rs,length=rs),sep="")[0:rs],
                          paste("br",seq(1,rr,length=rr),sep="")[0:rr],
  "s2a","sab","s2b","s2e","rho", paste("s2z",seq(1,k,length=k),sep="")[0:k] )
                } 
            
if(directed==F) {
cnames<-c("k","scan","ll",paste("bd",seq(1,rd,length=rd),sep="")[0:rd],"b0",
                          paste("bs",seq(1,rs,length=rs),sep="")[0:rs],
                "s2a","s2e",paste("s2z",seq(1,k,length=k),sep="")[0:k] )
                }

                 
###design matrix for unit-specific predictors
if(directed==T) {
X.u<<-rbind( cbind( rep(.5,n), Xs, matrix(0,nrow=n,ncol=rr)),
            cbind( rep(.5,n),  matrix(0,nrow=n,ncol=rs), Xr ) )
                 }

if(directed==F) { X.u<<-cbind( rep(.5,n), Xs )  }
###

###construct an upper triangular matrix (useful for later computations)
tmp<-matrix(1,n,n)
tmp[lower.tri(tmp,diag=T)]<-NA 
UT<<-tmp
###


###get starting values and empirical bayes priors using a glm-type approach
if(estart==T) {tmp<-gbme.glmstart(Y,Xd,Xs,Xr,N=N,fam,k,directed)
               priors<-tmp$priors ; startv<-tmp$startv 
              }

if(directed==T) {
 pi.Sab<-priors$pi.Sab; pi.s2u<-priors$pi.s2u; pi.s2v<-priors$pi.s2v
 pi.s2z<-priors$pi.s2z ; pim.bd<-priors$pim.bd ; piS.bd<-priors$piS.bd
 pim.b0sr<-priors$pim.b0sr ; piS.b0sr<-priors$piS.b0sr 
 beta.d<-startv$beta.d ; beta.u<-startv$beta.u 
 s<-startv$s ; r<-startv$r ; z<-startv$z
               }
###

if(directed == F) {  rho<-1  ;sv<-0 ;  Xr<-Xs ; rr<-rs 
                  pi.s2u<-priors$pi.s2u ; pi.s2z<-priors$pi.s2z 
                  pim.bd<-priors$pim.bd ; piS.bd<-priors$piS.bd
                  beta.d<-startv$beta.d ; beta.u<-startv$beta.u ; z<-startv$z
                  s<-startv$s ; 
                  pi.s2a<-priors$pi.s2a ; 
                  pim.b0s<-priors$pim.b0s ;  piS.b0s<-priors$piS.b0s 
                  Xr<-NULL ; rr<-0 ; r<-s*0   }

 
###Matrices for ANOVA  on Xd, s, r
tmp<-TuTv(n)   #unit level effects design matrix for u=yij+yji, v=yij-yji
Tu<-tmp$Tu
Tv<-tmp$Tv

if(directed==F) { Tu<-2*Tu[,1:n] }

tmp<-XuXv(Xd)   #regression design matrix for u=yij+yji, v=yij-yji
Xu<-tmp$Xu  
Xv<-tmp$Xv

XTu<<-cbind(Xu,Tu)
XTv<<-cbind(Xv,Tv)

tXTuXTu<<-t(XTu)%*%XTu
tXTvXTv<<-t(XTv)%*%XTv
###


###redefining hyperparams
if(directed==T){
Sab0<-matrix( c(pi.Sab[1],pi.Sab[2],pi.Sab[2],pi.Sab[3]),nrow=2,ncol=2) 
v0<-pi.Sab[4]   }
###

###initializing error matrix
E<-matrix(0,nrow=n,ncol=n)
###

###if using the linear link, then theta=Y
if(fam=="gaussian"){ theta<-Y }
###


##### The Markov chain Monte Carlo algorithm
for(ns in 1:NS){

###update value of theta
if(fam!="gaussian"){theta<-theta.betaX.d.srE.z(beta.d,Xd,s,s*(1-directed)+r*directed,E,z)  }

###impute any missing values if gaussian
if(fam=="gaussian" & any(is.na(Y))) {  
  rho<-(pi.s2u[2]-pi.s2v[2])/(pi.s2u[2]+pi.s2v[2])
  se<-(pi.s2u[2]+pi.s2v[2])/4
  mu<-theta.betaX.d.srE.z(beta.d,Xd,s,s*(1-directed)+r*directed,E*0,z)
  imiss<-(1:n)[ is.na(Y%*%rep(1,n))  ]
  for(i in imiss){
    for(j in (1:n)[is.na(Y[i,])]) {
    if( is.na(Y[i,j]) & is.na(Y[j,i]) )       {
      smp<-rmvnorm(c(mu[i,j],mu[j,i]),matrix( se*c(1,rho,rho,1),nrow=2,ncol=2))
      theta[i,j]<-smp[1] ; theta[j,i]<-smp[2] }
else{theta[i,j]<-rmvnorm( mu[i,j]+rho*(theta[j,i]-mu[j,i]), sqrt(se*(1-rho^2)))}
                                   }  
                  }           
                                    }  


###Update regression part
tmp<-uv.E(theta-z%*%t(z)) #the regression part
u<-tmp$u                  #u=yij+yji,  i<j
v<-tmp$v                  #v=yij-yji,  i<j

#First get variance - covariance terms
if(directed==T) {
su<-rse.beta.d.gibbs(pi.s2u[1],pi.s2u[2],u,XTu,s,r,beta.d)  #for rho, se
sv<-rse.beta.d.gibbs(pi.s2v[1],pi.s2v[2],v,XTv,s,r,beta.d)
rho<-(su-sv)/(su+sv)
se<-(su+sv)/4
                 }
if(directed==F) {
su<-rse.beta.d.gibbs(pi.s2u[1],pi.s2u[2],u,XTu,s,NULL,beta.d) #for se
se<-su/4       }


sr.hat<-X.u%*%beta.u                                        #Sab  
a<-s-sr.hat[1:n]
b<-r-sr.hat[n+(1:n)]
if( directed==T ) {Sab<-rSab.gibbs(a,b,Sab0,v0)}
if( directed==F ) { s2a<-1/rgamma( 1, pi.s2a[1]+n/2 , pi.s2a[2]+sum(a^2)/2 ) }

#dyad specific regression coef and unit level effects
mu<-c(pim.bd, X.u%*%beta.u)    #"prior" mean for (beta.d,s,r)
if(directed==T){
beta.d.sr<-rbeta.d.sr.gibbs(u,v,su,sv,piS.bd,mu,Sab) 
beta.d<-beta.d.sr$beta.d ; s<-beta.d.sr$s ; r<-beta.d.sr$r
#regression coef for unit level effects
beta.u<-rbeta.sr.gibbs(s,r,X.u,pim.b0sr,piS.b0sr,Sab)
                }
if(directed==F) {
beta.d.s<-rbeta.d.s.gibbs(u,su,piS.bd,mu,s2a)
beta.d<-beta.d.s$beta.d ; s<-beta.d.s$s
#regression coef for unit level effects
beta.u<-rbeta.s.gibbs(s,X.u,pim.b0s,piS.b0s,s2a)
                 }
###


###bilinear effects
if(k>0){

#update variance
#tmp<-eigen(z%*%t(z))
#z<-tmp$vec[,1:k]%*%sqrt(diag(tmp$val[1:k],nrow=k)) #make cols of z orthogonal  
sz<-1/rgamma(k,pi.s2z[,1]+n/2,pi.s2z[,2]+diag( t(z)%*%z)/2)

#Gibbs for zs, using regression
res<-theta-theta.betaX.d.srE.z(beta.d,Xd,s,s*(1-directed)+r*directed,0*E,0*z) #theta-(beta*x+a+b)
s.ares<-se*(1+rho)/2
for(i in sample(1:n))      {
ares<-(res[i,-i]+res[-i,i])/2
Zi<-z[-i,]
Szi<-chol2inv(chol(diag(1/(sz),nrow=k) + 
     t(Zi)%*%Zi/s.ares)) #cond variance of z[i,]
muzi<-Szi%*%( t(Zi)%*%ares/s.ares )                      #cond mean of z[i,]
z[i,]<-t(rmvnorm(muzi,Szi)) }
         }
###
if(k==0){sz<-NULL }

#update E
if( fam!="gaussian"){
E<-theta-theta.betaX.d.srE.z(beta.d,Xd,s,s*(1-directed)+r*directed,E*0,z) 
      #current E|beta.d,Xd,s,r,z

UU<-VV<-Y*0

u<-rnorm(n*(n-1)/2,0,sqrt(su))
v<-rnorm(n*(n-1)/2,0,sqrt(sv))

UU[!is.na(UT)]<-u
tmp<-t(UU)
tmp[!is.na(UT)]<-u
UU<-t(tmp)

VV[!is.na(UT)]<-v
tmp<-t(VV)
tmp[!is.na(UT)]<--v
VV<-t(tmp)

Ep<-(UU+VV)/2
theta.p<-theta-E+Ep

diag(theta.p)<-diag(theta)<-NA



##cases
if(fam=="poisson") { mup<-exp(theta.p) ;  mu<-exp(theta)
                     M.lhr<-dpois(Y,mup,log=T) - dpois(Y,mu,log=T)   }

if(fam=="binomial"){ mup<-exp(theta.p)/(1+exp(theta.p))
                          mu<-exp(theta)/(1+exp(theta))
         M.lhr<-dbinom(Y,N,mup,log=T) - dbinom(Y,N,mu,log=T)   }

   M.lhr[ is.na(M.lhr) ]<-0
   M.lhr<-(M.lhr+t(M.lhr))/( 2^(1-directed) )
   RU<-matrix(log(runif(n*n)),nrow=n,ncol=n)
   RU[is.na(UT)]<-0  ; RU<-RU+t(RU)
   E[M.lhr>RU]<-Ep[M.lhr>RU]
                 }




####output
if(ns%%odens==0){

#compute loglikelihoods of interest
if(fam=="poisson") { lpy.th<-sum( dpois(Y,exp(theta),log=T),na.rm=T) }
if(fam=="binomial"){ lpy.th<-sum( dbinom(Y,N,exp(theta)/(1+exp(theta)),
                                    log=T),na.rm=T) }

if(fam=="gaussian"){ 
E<-theta-theta.betaX.d.srE.z(beta.d,Xd,s,s*(1-directed)+r*directed,E*0,z)
tmp<-uv.E(theta-z%*%t(z)) #the regression part
u<-tmp$u                  #u=yij+yji,  i<j
v<-tmp$v                  #v=yij-yji,  i<j
if(directed==T) {
lpy.th<-sum(dnorm(u,0,sqrt(su),log=T) + dnorm(v,0,sqrt(sv),log=T)) }
if(directed==F) { lpy.th<-2*sum(dnorm(u,0,sqrt(su),log=T))  }
                    }
if(directed==F) {lpy.th<-lpy.th/2
                 out<-round(c(k,ns,lpy.th,beta.d,beta.u,s2a,se,sz[0:k]),oround) }
if(directed==T) {
out<-round(c(k,ns,lpy.th,beta.d,beta.u,Sab[1,1],Sab[1,2],Sab[2,2],
             se,rho,sz[0:k]),oround) }

if(owrite==T) { 
    if(ns==odens) { write.table(t(out),file=ofilename,quote=F,
                     row.names=F,col.names=cnames) }
    if(ns>odens)  { write.table(t(out),file=ofilename,append=T,quote=F,
                    row.names=F,col.names=F) }
              }
if(owrite==F) {cat(out,"\n") }
if(zwrite==T) { write.table(signif(z,sdigz),file=zfilename,
                      append=T*(ns>odens),quote=F,row.names=F,col.names=F) }


if(awrite==T){write.table(round(t(a),oround),file=afilename,append=T*(ns>odens),quote=F,
                    row.names=F,col.names=F)  }
if(bwrite==T & directed==T){write.table(round(t(b),oround),
                    file=bfilename,append=T*(ns>odens),quote=F,
                    row.names=F,col.names=F) }

                 }

}}

#####################End of main function : below are helper functions

####
TuTv<-function(n){
Xu<-Xv<-NULL
for(i in 1:(n-1)){
tmp<-tmp<-NULL
if( i >1 ){ for(j in 1:(i-1)){ tmp<-cbind(tmp,rep(0,n-i)) } }
tmp<-cbind(tmp,rep(1,n-i)) 
tmpu<-cbind(tmp,diag(1,n-i)) ; tmpv<-cbind(tmp,-diag(1,n-i))
Xu<-rbind(Xu,tmpu) ; Xv<-rbind(Xv,tmpv)
         }

list(Tu=cbind(Xu,Xu),Tv=cbind(Xv,-Xv))
                   }
####

XuXv<-function(X){
Xu<-Xv<-NULL
if(dim(X)[3]>0){
for(r in 1:dim(X)[3]){
xu<-xv<-NULL
for(i in 1:(n-1)){
for(j in (i+1):n){ xu<-c(xu,X[i,j,r]+X[j,i,r])
                   xv<-c(xv,X[i,j,r]-X[j,i,r]) }}
Xu<-cbind(Xu,xu)
Xv<-cbind(Xv,xv)  } 
                }
list(Xu=Xu,Xv=Xv)}

###
uv.E<-function(E){
u<- c(  t( (  E + t(E) )  *UT ) )
u<-u[!is.na(u)]

v<-c(  t( (  E - t(E) )  *UT ) )
v<-v[!is.na(v)]
list(u=u,v=v)}
####



####
theta.betaX.d.srE.z<-function(beta.d,X.d,s,r,E,z){
m<-dim(X.d)[3]
mu<-matrix(0,nrow=length(s),ncol=length(s))
if(m>0){for(l in 1:m){ mu<-mu+beta.d[l]*X.d[,,l] }}
tmp<-mu+re(s,r,E,z)
diag(tmp)<-0
tmp}
####

####
re<-function(a,b,E,z){
n<-length(a)
matrix(a,nrow=n,ncol=n,byrow=F)+matrix(b,nrow=n,ncol=n,byrow=T)+E+z%*%t(z) }
####

####
rbeta.d.sr.gibbs<-function(u,v,su,sv,piS.bd,mu,Sab){
del<-Sab[1,1]*Sab[2,2]-Sab[1,2]^2
iSab<-rbind(cbind( diag(rep(1,n))*Sab[2,2]/del ,-diag(rep(1,n))*Sab[1,2]/del),
          cbind( -diag(rep(1,n))*Sab[1,2]/del,diag(rep(1,n))*Sab[1,1]/del) )
rd<-dim(as.matrix(piS.bd))[1]

if(dim(piS.bd)[1]>0){
cov.beta.sr<-matrix(0,nrow=rd,ncol=2*n)
iS<-rbind(cbind(solve(piS.bd),cov.beta.sr),
   cbind(t(cov.beta.sr),iSab)) }
else{iS<-iSab}

Sig<-chol2inv( chol(iS + tXTuXTu/su + tXTvXTv/sv ) )
    #this may have a closed form expression

#theta<-Sig%*%( (t(XTu)%*%u)/su + (t(XTv)%*%v)/sv + iS%*%mu)
theta<-Sig%*%( t(  (u%*%XTu)/su + (v%*%XTv)/sv ) + iS%*%mu)

beta.sr<-rmvnorm(theta,Sig)
list(beta.d=beta.sr[(rd>0):rd],s=beta.sr[rd+1:n],r=beta.sr[rd+n+1:n]) }
####


####
rse.beta.d.gibbs<-function(g0,g1,x,XTx,s,r,beta.d){
n<-length(s)
1/rgamma(1, g0+choose(n,2)/2,g1+.5*sum( (x-XTx%*%c(beta.d,s,r))^2 ) ) }
####


####
rbeta.sr.gibbs<-function(s,r,X.u,pim.b0sr,piS.b0sr,Sab) {
del<-Sab[1,1]*Sab[2,2]-Sab[1,2]^2
iSab<-rbind(cbind( diag(rep(1,n))*Sab[2,2]/del ,-diag(rep(1,n))*Sab[1,2]/del),
          cbind( -diag(rep(1,n))*Sab[1,2]/del,diag(rep(1,n))*Sab[1,1]/del) )

S<-solve( solve(piS.b0sr) + t(X.u)%*%iSab%*%X.u )
mu<-S%*%(  solve(piS.b0sr)%*%pim.b0sr+ t(X.u)%*%iSab%*%c(s,r))
rmvnorm( mu,S)
                                               }
####

####
rSab.gibbs<-function(a,b,S0,v0){
n<-length(a)
ab<-cbind(a,b)
Sn<-S0+ (t(ab)%*%ab)
solve(rwish(solve(Sn),v0+n) )
                               }

####
rmvnorm<-function(mu,Sig2){
R<-t(chol(Sig2))
R%*%(rnorm(length(mu),0,1)) +mu }


####
rwish<-function(S0,nu){ 
S<-S0*0
for(i in 1:nu){ z<-rmvnorm(rep(0,dim(as.matrix(S0))[1]), S0)
                S<-S+z%*%t(z)  }
		S }

###  Procrustes transformation: rotation and reflection
proc.rr<-function(Y,X){
k<-dim(X)[2]
A<-t(Y)%*%(  X%*%t(X)  )%*%Y
eA<-eigen(A,symmetric=T)
Ahalf<-eA$vec[,1:k]%*%diag(sqrt(eA$val[1:k]),nrow=k)%*%t(eA$vec[,1:k])
                                                                                  
t(t(X)%*%Y%*%solve(Ahalf)%*%t(Y)) }
###



gbme.glmstart<-function(Y,Xd,Xs,Xr,N=NULL,fam,k,directed){  
#generate starting values and emp bayes priors from 
#approximate mles

if(fam!="binomial"){
y<-x<-NULL
for (i in 1:n) {
for (j in (1:n)[-i]) {
y<-c(y,Y[i,j])
x<-rbind(x,c(i,j,Xd[i,j,])) }}
                    }

if(fam=="binomial"){
y<-x<-NULL
for (i in 1:n) {
for (j in (1:n)[-i]) {
y<-rbind(y,c(Y[i,j], N[i,j]-Y[i,j] ))
x<-rbind(x,c(i,j,Xd[i,j,])) }}
                    }


if(rd>0) {
 fit1<-glm(y~-1+as.factor(x[,1])+as.factor(x[,2])+x[,-(1:2)],family=fam) }
if(rd==0){ fit1<-glm(y~-1+as.factor(x[,1])+as.factor(x[,2]),family=fam) }
                                                                                  
s<-fit1$coef[1:n]
r<-c(0,fit1$coef[n+1:(n-1)])
if(rd>0){
beta.d<-fit1$coef[(2*n):length(fit1$coef)]               #beta.d
        }
                                                                                  
la<-lm( s~-1+cbind(rep(.5,n),Xs)); a<-la$res
lb<-lm( r~-1+cbind(rep(.5,n),Xr)); b<-lb$res
                                                                                  
b0<-(la$coef[1]+lb$coef[1])/2
                                                                                  
s1<-s+( b0-la$coef[1])/2                 #s
r1<-r+( b0-lb$coef[1])/2                 #r
                                                                                  
la<-lm( s1~-1+cbind(rep(.5,n),Xs)); a<-la$res
lb<-lm( r1~-1+cbind(rep(.5,n),Xr)); b<-lb$res
                                                                                  
beta.u<-c(lb$coef[1], la$coef[-1],lb$coef[-1])
Sab<-var(cbind(a,b))                    #Sab

Res<-matrix(0,nrow=n,ncol=n)
l<-1 
for( m in 1:dim(x)[1] ) {
if( !is.na(y[m]) ) { Res[x[m,1],x[m,2]]<-fit1$res[l] ; l<-l+1 }
                         }
######
Res[Res>quantile(Res,.95,na.rm=T) ] <- quantile(Res,.95,na.rm=T)
diag(Res)<-rep(0,n)
                                                                                  
if(k>0){
for(i in 1:50){
tmp<-eigen( .5*(Res+t(Res) ))
z<-tmp$vec[,1:k] %*%diag(sqrt(tmp$val[1:k]),nrow=k)
diag(Res)<-diag(z%*%t(z))
                 }
sz<-var(c(z))                         #z,sz
E<-Res-z%*%t(z)                           #E
          }
if(k==0){E<-Res ; z<-matrix(0,nrow=n,ncol=1) ;sz<-.1}

u<-E+t(E)
u<-c(u[!is.na(UT)])                      #su
su<-var(u)                               #sv
v<-E-t(E)
v<-c(v[!is.na(UT)])
sv<-var(v)
                                                                                  
rho<-(su-sv)/(su+sv)
se<-(su+sv)/4


###construct priors centered on these empirical values
pi.Sab<-c(Sab[1,1],Sab[2,1],Sab[2,2],4)
pi.s2u<-c(2,su)
pi.s2v<-c(2,sv)
pi.s2z<-cbind( rep(2,k), diag( t(z)%*%z)/n )
                                                                                  
if(rd>0){
pim.bd<-c(beta.d)
piS.bd<-as.matrix((n*(n-1))^2*summary(fit1)$cov.unscaled[(2*n):length(fit1$coef),
                                          (2*n):length(fit1$coef)] )
         }
                                                                                  
                                                                                  
if(rd==0){ beta.d<-pim.bd<-NULL ;  piS.bd<-matrix(nrow=0,ncol=0) }
                                                                                  
if(directed==T) {
pim.b0sr<-beta.u
piS.b0sr<-rbind(cbind( summary(la)$cov[-1,-1], matrix(0,nrow=rs,ncol=rr)),
# cbind(matrix(0,nrow=rs,ncol=rr),summary(lb)$cov[-1,-1]))
# error found 7-7-6
  cbind(matrix(0,nrow=rr,ncol=rs),summary(lb)$cov[-1,-1]))

piS.b0sr<-rbind(c(summary(la)$cov[1,-1],summary(lb)$cov[1,-1]),piS.b0sr)
piS.b0sr<-cbind(c(summary(la)$cov[1,1:(rs+1)],
                  summary(lb)$cov[1,-1]),piS.b0sr)
piS.b0sr<-as.matrix(piS.b0sr*n*n) 

pim.b0s<-NULL ; piS.b0s<-NULL  ;pi.s2a<-NULL
                }
if(directed==F) { pim.b0sr<-NULL ; piS.b0sr<-NULL ; pi.Sab<-NULL
                  s<-(s+r)/2  ; r<-s*0
                  tmp2<-lm(s~-1+cbind( rep(.5,n),Xs)) 
                  beta.u<-tmp2$coef ; pi.s2a<-c(2,var(tmp2$res)) ;
                  pim.b0s<-tmp2$coef ; piS.b0s<-summary(tmp2)$cov*n*n }



###
list( priors=list(pi.Sab=pi.Sab,pi.s2u=pi.s2u,pi.s2v=pi.s2v,pi.s2z=pi.s2z,
                  pim.bd=pim.bd,piS.bd=piS.bd,
                  pim.b0sr=pim.b0sr,piS.b0sr=piS.b0sr,
                  pim.b0s=pim.b0s, piS.b0s=piS.b0s , pi.s2a=pi.s2a) ,
      startv=list(beta.d=beta.d,beta.u=beta.u,s=s,r=r,z=z)
     )
}


####
rbeta.d.s.gibbs<-function(u,su,piS.bd,mu,s2a){
iSa<-diag(rep(1/s2a,n))

if(dim(piS.bd)[1]>0){
cov.beta.s<-matrix(0,nrow=rd,ncol=n)
iS<-rbind(cbind(solve(piS.bd),cov.beta.s),
   cbind(t(cov.beta.s),iSa)) }
else{iS<-iSa}

Sig<-chol2inv( chol(iS + tXTuXTu/su ) )
    #this may have a closed form expression

theta<-Sig%*%( t(  (u%*%XTu)/su) + iS%*%mu)

beta.s<-rmvnorm(theta,Sig)
list(beta.d=beta.s[(rd>0):rd],s=beta.s[rd+1:n]) }
####

####
rbeta.s.gibbs<-function(s,X.u,pim.b0s,piS.b0s,s2a) {
iSa<-diag(rep(1/s2a,n))

S<-solve( solve(piS.b0s) + t(X.u)%*%iSa%*%X.u )
mu<-S%*%(  solve(piS.b0s)%*%pim.b0s+ t(X.u)%*%iSa%*%s)
rmvnorm( mu,S)
                                               }

EOF
}

# --------------------------------------------------
sub template_sna {
    return <<EOF
setwd("[% out_dir %]")
source("gbme.R")
library(xtable)
NS <- [% num_scans OR '100000' %]
odens <- 10
Y <- as.matrix(read.table("[% seq_matrix %]", header = TRUE))
n <- nrow(Y)
k <- [% meta.size %]
Xss<-array(NA, dim=c(n,n,k))
[% SET counter = 0 -%]
[% SET meta_names = [] %]
[% FOREACH metafile IN meta -%]
[% SET counter=counter + 1 -%]
[% metafile %] <- as.matrix(read.table("[% metafile %]", header = TRUE))
Xss[,, [% counter%] ] <- [% metafile %]
[% meta_names.push(m.name) -%]
[% END -%]
[% SET counter=counter + 1 -%]

gbme(Y=Y, Xss, fam="gaussian", k=2, direct=F, NS=NS, odens=odens)

x.names <- c("[% meta_names.join('", "')%]", "intercept")

OUT <- read.table("OUT", header=T)
full.model <- t(apply(OUT, 2, quantile, c(0.5, 0.025, 0.975)))
rownames(full.model)[1:[% counter %]] <- x.names
table1 <- xtable(full.model[1:[% counter %],], align="c|c||cc")
print ( xtable (table1), type= "latex" , file= "table1.tex" )
EOF
}

# --------------------------------------------------
sub template_plot {
    return <<EOF
setwd("[% out_dir %]")
source("gbme.R")
OUT<-read.table("OUT",header=T)
#examine marginal mixing
par(mfrow=c(3,4))      
pdf("plot1.pdf", width=6, height=6)
for(i in 3:dim(OUT)[2]) { plot(OUT[,i],type="l") }
dev.off()
# posterior samples, dropping
# the first half of the chain
# to allow for burn in
PS<-OUT[OUT\$scan>round(max(OUT\$scan)/2),-(1:3)]

#gives mean, std dev, and .025,.5,.975 quantiles
M.SD.Q<-rbind( apply(PS,2,mean),apply(PS,2,sd),apply(PS,2,quantile,probs=c(.025,.5,.975)) )

print(M.SD.Q)

#plots of posterior densities
pdf("plot2.pdf", width=6, height=6)
par(mfrow=c(3,4))
for(i in 1:dim(PS)[2]) { plot(density(PS[,i]),main=colnames(PS)[i]) }
dev.off()

###analysis of latent positions

Z<-read.table("Z")

#convert to an array
nss<-dim(OUT)[1]
n<-dim(Z)[1]/nss
k<-dim(Z)[2]
PZ<-array(dim=c(n,k,nss))
for(i in 1:nss) { PZ[,,i]<-as.matrix(Z[ ((i-1)*n+1):(i*n) ,])  }

PZ<-PZ[,,-(1:round(nss/2))]     #drop first half for burn in

#find posterior mean of Z %*% t(Z)
ZTZ<-matrix(0,n,n)
for(i in 1:dim(PZ)[3] ) { ZTZ<-ZTZ+PZ[,,i]%*%t(PZ[,,i]) }
ZTZ<-ZTZ/dim(PZ)[3]

#a configuration that approximates posterior mean of ZTZ
tmp<-eigen(ZTZ)
Z.pm<-tmp\$vec[,1:k]%*%sqrt(diag(tmp\$val[1:k]))

#now transform each sample Z to a common orientation
for(i in 1:dim(PZ)[3] ) { PZ[,,i]<-proc.rr(PZ[,,i],Z.pm) }

#
# a two dimensional plot of "mean" latent locations 
# and marginal confidence regions
#
k <- 2
if(k==2) {     

    r<-atan2(Z.pm[,2],Z.pm[,1])
    r<-r+abs(min(r))
    r<-r/max(r)
    g<-1-r
    b<-(Z.pm[,2]^2+Z.pm[,1]^2)
    b<-b/max(b)

    par(mfrow=c(1,1))
    pdf("sna-gbme.pdf", width=6, height=6)
    plot(Z.pm[,1],Z.pm[,2],xlab="",ylab="",type="n",xlim=range(PZ[,1,]),
         ylim=range(PZ[,2,]))
    abline(h=0,lty=2);abline(v=0,lty=2)

    for(i in 1:n) { points( PZ[i,1,],PZ[i,2,],pch=46,col=rgb(r[i],g[i],b[i]) ) }
    [% SET labels = [] %]
    [% FOREACH id IN samples -%]
       [% labels.push("'" _ id _ "'") -%]
    [% END -%]
    text(Z.pm[,1],Z.pm[,2], cex = 0.3, labels=c([% labels.join(',') %]))   #add labels here
    dev.off()
}
EOF
}

# --------------------------------------------------
sub distance_metadata_matrix {
    #
    # This routine creates the metadata distance matrix based on lat/lon 
    #
    # in_file contains sample, latitude, and longitude in K (Kilometers)
    # similarity distance is equal to the max distances in K for samples to be
    # considered "close", default = 1000
    my ($in_file, $similarity_distance, $out_dir) = @_;
    open my $IN, '<', $in_file;
    my @meta               = ();
    my %sample_to_metadata = ();
    my @samples;
    my $pi = atan2(1, 1) * 4;

    # a test and expected degrees
    #print distance(32.9697, -96.80322, 29.46786, -98.53506, "M") . " Miles\n";
    #print distance(32.9697, -96.80322, 29.46786, -98.53506, "K") . " Kilometers\n";
    #print distance(32.9697, -96.80322, 29.46786, -98.53506, "N") . " Nautical Miles\n";

    my $i = 0;
    while (<$IN>) {
        $i++;
        chomp $_;

        if ($i == 1) {
            @meta = split(/\t/, $_);
            shift @meta;    # remove id
        }
        else {
            my ($id, @values) = split(/\t/, $_);
            push @samples, $id;
            for my $m (@meta) {
                my $v = shift @values;
                $sample_to_metadata{$id}{$m} = $v;
            }
        }
    }

    # create a file that calculates the distance between two geographic points
    # for each pairwise combination of samples
    my $basename = basename($in_file);
    my $out_file = catfile($out_dir, "${basename}.meta");
    open my $OUT, '>', $out_file;
    say $OUT join "\t", '', @samples;

    # approximate radius of earth in km
    #my $r = 6373.0;

    my %check;
    for my $id (sort @samples) {
        my @dist = ();
        for my $s (@samples) {
            my @a = ();    #metavalues for A lat/lon
            my @b = ();    #metavalues for B lat/lon
            for my $m (@meta) {
                my $s1 = $sample_to_metadata{$id}{$m};
                my $s2 = $sample_to_metadata{$s}{$m};
                if (($s1 eq 'NA') || ($s2 eq 'NA')) {
                    $s1 = 0;
                    $s2 = 0;
                }
                push(@a, $s1);
                push(@b, $s2);
            }

            #pairwise dist in km between A and B
            my $lat1 = $a[0];
            my $lat2 = $b[0];
            my $lon1 = $a[1];
            my $lon2 = $b[1];
            my $unit = 'K';
            my $d    = 0;
            if (($lat1 != $lat2) && ($lon1 != $lon2)) {
                $d = distance($lat1, $lon1, $lat2, $lon2, $unit);
            }

            # close = 1
            # far = 0
            my $closeness = 0;
            if ($d < $similarity_distance) {
                $closeness = 1;
            }
            push @dist, $closeness;

        }

        my $tmp = join('', @dist);
        $check{ $tmp }++;
        say $OUT join "\t", $id, @dist;
    }

    if (meta_dist_ok(\%check)) {
        return $out_file;
    }
    else {
        debug("EXCLUDE");
        return undef;
    }
}

# --------------------------------------------------
sub meta_dist_ok {
    my $dist = shift;

    debug("dist = ", dump($dist));
    return unless ref($dist) eq 'HASH';

    my @keys      = keys(%$dist) or return;
    my $n_keys    = scalar(@keys);
    my $n_samples = sum(values(%$dist));
    my @dists     = map { sprintf('%.02f', ($dist->{$_} / $n_samples) * 100) }
                    @keys;

    debug("dists = ", join(', ', @dists));

    my @not_ok = grep { $_ >= $META_PCT_UNIQ } @dists;

    return @not_ok == 0;
}

# --------------------------------------------------
sub distance {
    #
    # This routine calculates the distance between two points (given the     
    # latitude/longitude of those points). It is being used to calculate     
    # the distance between two locations                                     
    #                                                                        
    # Definitions:                                                           
    #   South latitudes are negative, east longitudes are positive           
    #                                                                        
    # Passed to function:                                                    
    #   lat1, lon1 = Latitude and Longitude of point 1 (in decimal degrees)  
    #   lat2, lon2 = Latitude and Longitude of point 2 (in decimal degrees)  
    #   unit = the unit you desire for results                               
    #          where: 'M' is statute miles (default)                         
    #                 'K' is kilometers                                      
    #                 'N' is nautical miles                                  
    #
    my ($lat1, $lon1, $lat2, $lon2, $unit) = @_;

    my $theta = $lon1 - $lon2;
    my $dist =
      sin(deg2rad($lat1)) * sin(deg2rad($lat2)) +
      cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * cos(deg2rad($theta));
    $dist = acos($dist);
    $dist = rad2deg($dist);
    $dist = $dist * 60 * 1.1515;
    if ($unit eq "K") {
        $dist = $dist * 1.609344;
    }
    elsif ($unit eq "N") {
        $dist = $dist * 0.8684;
    }
    return ($dist);
}
 
# --------------------------------------------------
sub acos {
    #
    # This function get the arccos function using arctan function
    #
    my ($rad) = @_;
    my $ret = atan2(sqrt(1 - $rad**2), $rad);
    return $ret;
}
 
# --------------------------------------------------
sub deg2rad {
    #
    # This function converts decimal degrees to radians
    #
    my ($deg) = @_;
    my $pi = atan2(1,1) * 4;
    return ($deg * $pi / 180);
}
 
# --------------------------------------------------
sub rad2deg {
    #
    # This function converts radians to decimal degrees 
    #
    my ($rad) = @_;
    my $pi = atan2(1,1) * 4;
    return ($rad * 180 / $pi);
}

# --------------------------------------------------
sub continuous_metadata_matrix {
    # 
    # This routine creates the metadata matrix based on continuous
    # data values in_file contains sample, metadata (continous values)
    # e.g. temperature euclidean distance percentage = the bottom X
    # percent when sorted low to high considered "close", default =
    # bottom 10 percent
    #

    my ($in_file, $eucl_dist_per, $out_dir) = @_;
    open my $IN, '<', $in_file;

    my (@meta, %sample_to_metadata, @samples);

    my $i = 0;
    while (<$IN>) {
        $i++;
        chomp $_;

        if ($i == 1) {
            @meta = split(/\t/, $_);
            shift @meta;    # remove id
        }
        else {
            my @values = split(/\t/, $_);
            my $id = shift @values;
            push(@samples, $id);
            for my $m (@meta) {
                my $v = shift @values;
                $sample_to_metadata{$id}{$m} = $v;
            }
        }
    }

    unless (%sample_to_metadata) {
        die "Failed to get any metadata from file '$in_file'\n";
    }

    # create a file that calculates the euclidean distance for each value in
    # the metadata file for each pairwise combination of samples where the
    # value gives the euclidean distance for example "nutrients" might be
    # comprised of nitrite, phosphate, silica
    my $basename = basename($in_file);
    my $out_file = catfile($out_dir, "${basename}.meta");
    open my $OUT, '>', $out_file;
    say $OUT join "\t", '', @samples;

    # get all euc distances to determine what is reasonably "close"
    my @all_euclidean = ();
    for my $id (@samples) {
        my @pw_dist = ();
        for my $s (@samples) {
            my (@a, @b); 
            for my $m (@meta) {
                push @a, $sample_to_metadata{$id}{$m};
                push @b, $sample_to_metadata{$s}{$m};
            }

            #pairwise euc dist between A and B
            my $ct  = scalar(@a) - 1;
            my $sum = 0;
            for my $i (0 .. $ct) {
                if (($a[$i] ne 'NA') && ($b[$i] ne 'NA')) {
                    $sum += ($a[$i] - $b[$i])**2;
                }
            }

            # we have a sample that is different s1 ne s2
            # there are no 'NA' values
            if ($sum > 0) {
                my $euc_dist = sqrt($sum);
                push @all_euclidean, $euc_dist;
            }
        }
    }

    unless (@all_euclidean) {
        die "Failed to get Euclidean distances.\n";
    }

    my @sorted     = sort { $a <=> $b } @all_euclidean;
    my $count      = scalar(@sorted);
    my $bottom_per = $count - int($eucl_dist_per * $count);
    my $max_value  = $bottom_per < $count ? $sorted[$bottom_per] : $sorted[-1];
    my $min_value  = $sorted[0];
    debug(join(', ',
        "sorted (" . join(', ', @sorted) . ")",
        "eucl_dist_per ($eucl_dist_per)",
        "bottom_per ($bottom_per)", 
        "max_value ($max_value)", 
        "min_value ($min_value)"
    ));

    unless ($max_value > 0) {
        die "Failed to get valid max value from list ", join(', ', @sorted);
    }

    my %check;
    for my $id (sort @samples) {
        my (@pw_dist, @euclidean_dist);

        for my $s (@samples) {
            my (@a, @b);

            for my $m (@meta) {
                push @a, $sample_to_metadata{$id}{$m};
                push @b, $sample_to_metadata{$s}{$m};
            }

            my $ct  = scalar(@a) - 1;
            my $sum = 0;

            #pairwise euc dist between A and B
            for my $i (0 .. $ct) {
                if (($a[$i] ne 'NA') && ($b[$i] ne 'NA')) {
                    my $value = ($a[$i] - $b[$i])**2;
                    $sum = $sum + $value;
                }
            }

            if ($sum > 0) {
                my $euc_dist = sqrt($sum);
                push @euclidean_dist, $euc_dist;
            }
            else {
                if ($id eq $s) {
                    push @euclidean_dist, $min_value;
                }
                else {
                    #push @euclidean_dist, 'NA';
                    push @euclidean_dist, 0;
                }
            }
        }

        # close = 1
        # far = 0
        for my $euc_dist (@euclidean_dist) {
            my $val = ($euc_dist < $max_value) && ($euc_dist > 0) ? 1 : 0;
            push @pw_dist, $val;
        }

        my $tmp = join('', @pw_dist);
        $check{ $tmp }++;
        say $OUT join "\t", $id, @pw_dist;
    }

    if (meta_dist_ok(\%check)) {
        return $out_file;
    }
    else {
        debug("EXCLUDE");
        return undef;
    }
}

# --------------------------------------------------
sub discrete_metadata_matrix {
    #
    # This routine creates the metadata matrix based on discrete data values 
    #
    # in_file contains sample, metadata (discrete values) 
    # e.g. longhurst province
    # where 0 = different, and 1 = the same

    my ($in_file, $out_dir) = @_;
    my @meta               = ();
    my %sample_to_metadata = ();
    my @samples;

    open my $IN, '<', $in_file;

    my $i = 0;
    while (<$IN>) {
        $i++;
        chomp $_;

        # header line
        if ($i == 1) {
            @meta = split(/\t/, $_);
            shift @meta;    # remove id for sample
        }
        else {
            my @values = split(/\t/, $_);
            my $id = shift @values;
            push @samples, $id;
            for my $m (@meta) {
                my $v = shift @values;
                $sample_to_metadata{$id}{$m} = $v;
            }
        }
    }

    # create a file that calculates the whether each value in the metadata file
    # is the same or different
    # for each pairwise combination of samples
    # where 0 = different, and 1 = the same
    my $basename = basename($in_file);
    my $out_file = catfile($out_dir, "${basename}.meta");
    open my $OUT, ">", $out_file;
    say $OUT join "\t", '', @samples;

    my %check;
    for my $id (sort @samples) {
        my @same_diff = ();
        for my $s (@samples) {
            my @a = ();    #metavalues for A
            my @b = ();    #metavalues for B
            for my $m (@meta) {
                my $s1 = $sample_to_metadata{$id}{$m};
                my $s2 = $sample_to_metadata{$s}{$m};
                push(@a, $s1);
                push(@b, $s2);
            }

            # count for samples
            my $ct = @a;
            $ct = $ct - 1;

            #pairwise samenesscheck between A and B
            for my $i (0 .. $ct) {
                if (($a[$i] ne 'NA') && ($b[$i] ne 'NA')) {
                    if ($a[$i] eq $b[$i]) {
                        push @same_diff, 1;
                    }
                    else {
                        push @same_diff, 0;
                    }
                }
                else {
                    push @same_diff, 0;
                }
            }
        }

        my $tmp = join '', @same_diff;
        $check{ $tmp }++;
        say $OUT join "\t", $id, @same_diff;
    }

    close $OUT;

    if (meta_dist_ok(\%check)) {
        return $out_file;
    }
    else {
        debug("EXCLUDE");
        return undef;
    }
}

# --------------------------------------------------
sub debug {
    if ($DEBUG && @_) {
        say @_;
    }
}

__END__

# --------------------------------------------------

=pod

=head1 NAME

sna.pl - social-network analysis

=head1 SYNOPSIS

  sna.pl -o out-dir -m metadata -s seq-matrix

Required Arguments:

  -o|--out-dir     Path to output directory
  -m|--metadir     Path to metadata files
  -s|--seq-matrix  Path to sequence matrix file

Options:

  -e|eucdistper    Eucledean distance percentage (bottom 10% by default)
  -d|sampledist    Maximimum physical distance b/w samples to be called "close" (default 1000 K)  
  -v|--verbose     Be chatty (default yes)
  --help           Show brief help and exit
  --man            Show full documentation

=head1 DESCRIPTION

(1) Creates metadata files that are in matrix format for R
to show similarities and differences for each pairwise 
sample combination

The "metadata" file should look something like this:

        SMAD3+  Hel+
    DNA1    1   1
    DNA2    0   1
    DNA3    1   0
    DNA4    0   0

(2) Creates the R code for running the SNA analysis

(3) Runs the R code for the SNA analysis

=head1 AUTHORS

Bonnie Hurwitz E<lt>bhurwitz@email.arizona.eduE<gt>,
Ken Youens-Clark E<lt>kyclark@email.arizona.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2015 Hurwitz Lab

This module is free software; you can redistribute it and/or
modify it under the terms of the GPL (either version 1, or at
your option, any later version) or the Artistic License 2.0.
Refer to LICENSE for the full license text and to DISCLAIMER for
additional warranty disclaimers.

=cut
