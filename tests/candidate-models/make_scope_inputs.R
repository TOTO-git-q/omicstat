E <- commandArgs(TRUE)[1]
dir.create(E,recursive=TRUE,showWarnings=FALSE)
set.seed(713)
dir.create(E,showWarnings=FALSE)
plate <- data.frame()
well <- function(role,id,x,dil,y) data.frame(plate_id='Plate01',well=sprintf('W%03d',seq_along(y)+nrow(plate)),role=role,sample_id=id,concentration=x,dilution=dil,response=y)
plate <- rbind(plate,well('blank','blank',NA,1,c(.05,.052,.048,.051)))
x <- c(.02,.05,.15,.5,1.5,5,15,50,150)
f <- function(x) .05+2.6/(1+exp(-1.3*(log(x)-log(3))))
for(z in x) plate <- rbind(plate,well('standard',paste0('S',z),z,1,f(z)+rnorm(3,0,.006)))
for(i in 1:12) {z <- c(.001,.4,.8,1.2,2,3,4,7,12,20,60,300)[i];plate <- rbind(plate,well('unknown',sprintf('Donor%02d',i),NA,c(1,10,20)[(i-1)%%3+1],f(z)+rnorm(3,0,.004)))}
write.csv(plate,file.path(E,'plate.csv'),row.names=FALSE,na='')
plate5 <- plate
# Asymmetric standard means make LL5 identifiable.
f5 <- function(x) .05+2.6/(1+exp(-1.3*(log(x)-log(3))))^1.7
for(i in which(plate5$role=='standard')) plate5$response[i] <- f5(plate5$concentration[i])+rnorm(1,0,.003)
for(i in which(plate5$role=='unknown')) plate5$response[i] <- .8+rnorm(1,0,.004)
write.csv(plate5,file.path(E,'plate5.csv'),row.names=FALSE,na='')
plate <- plate[plate$role=='blank',]
for(i in 1:3) for(z in 10*2^(0:9)) plate <- rbind(plate,well('unknown',paste0('Serum',i),NA,z,.05+2.4/(1+(z/(200*i))^1.4)+rnorm(3,0,.008)))
write.csv(plate,file.path(E,'titer.csv'),row.names=FALSE,na='')
d <- expand.grid(dose=c(.01,.03,.1,.3,1,3,10,30),subject=sprintf('D%02d',1:16)); shifts <- rnorm(16,0,.5)
d$response <- 100/(1+exp(-(log(d$dose)-log(1.6)-shifts[match(d$subject,unique(d$subject))])/.7))+rnorm(nrow(d),0,2)
write.csv(d,file.path(E,'repeated.csv'),row.names=FALSE)
d$response <- 110-d$response-10
write.csv(d,file.path(E,'repeated_decreasing.csv'),row.names=FALSE)
