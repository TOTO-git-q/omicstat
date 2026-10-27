E <- commandArgs(TRUE)[1]
dir.create(E,recursive=TRUE,showWarnings=FALSE)
dir.create(E,showWarnings=FALSE)
w <- function(x,nm) write.csv(x,file.path(E,nm),row.names=FALSE,na='NA')
w(transform(drc::ryegrass,unit=seq_len(nrow(drc::ryegrass))),'ryegrass.csv')
s <- lme4::sleepstudy;s$period <- ifelse(s$Days<5,'early','late');s$cohort <- ifelse(as.integer(s$Subject)%%2==0,'one','two');w(s,'sleepstudy.csv')
set.seed(20261015)
syn <- proDA::generate_synthetic_data(n_proteins=500,n_conditions=2)
m <- syn$Y;w(data.frame(feature_id=rownames(m),m,check.names=FALSE),'proteins.csv')
w(data.frame(sample=colnames(m),biological_id=colnames(m),condition=syn$groups),'samples.csv')
x <- expand.grid(ProteinName=paste0('p',1:30),PeptideModifiedSequence=paste0('pep',1:3),Run=paste0('run',1:6),stringsAsFactors=FALSE)
x$PeptideModifiedSequence <- paste(x$ProteinName,x$PeptideModifiedSequence,sep='_')
x$Condition <- ifelse(as.integer(sub('run','',x$Run))<=3,'A','B');x$BioReplicate<-x$Run
x$PrecursorCharge<-2L;x$FragmentIon<-NA_character_;x$ProductCharge<-NA_integer_;x$IsotopeLabelType<-'L';x$Fraction<-1L
x$Intensity<-2^(20+as.integer(sub('p','',x$ProteinName))/10+as.integer(sub('.*pep','',x$PeptideModifiedSequence))/5+ifelse(x$Condition=='B'&x$ProteinName %in% paste0('p',1:5),2,0)+rnorm(nrow(x),sd=.2));w(x,'msstats_long.csv')
# Explicit simulation of raw OD plate: three biological samples/dilution,
# duplicate technical wells and blank wells; blank subtraction/duplicate means
# happen upstream and never inflate biological n.
p <- expand.grid(dose=c(0,.01,.03,.1,.3,1,3,10,30),biological=1:3,technical=1:2)
p$biological_id<-paste(p$dose,p$biological,sep='_');p$OD<-0.05+2/(1+(.7/pmax(p$dose,1e-10))^1.2)+rnorm(nrow(p),sd=.015)
blanks<-data.frame(dose=0,biological=NA,technical=1:4,biological_id='blank',OD=c(.049,.051,.05,.05))
plate<-rbind(p,blanks);i<-seq_len(nrow(plate))-1L
plate<-data.frame(plate_id='ELISA-DEMO-001',well=paste0(LETTERS[i%/%12L+1L],i%%12L+1L),plate,check.names=FALSE)
w(plate,'elisa_raw_plate.csv');p$OD<-p$OD-mean(blanks$OD)
agg<-aggregate(OD~dose+biological_id,p,mean);w(agg,'elisa_curated.csv')
