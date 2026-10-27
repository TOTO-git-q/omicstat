# Maintenance: retain module call declarations only at actual module call sites.
# Shared API snapshots remain archived for reviewers; this never invents defaults.
source('skills/_shared/scripts/calls_check.R')
for(m in c('drc-dose','lme4-lmm','emmeans-contrast')) {
 p<-file.path('skills',m,'scripts/calls_registry.json');reg<-jsonlite::read_json(p)
 sites<-unlist(lapply(list.files(file.path('skills',m,'scripts'),pattern='\\.R$',full.names=TRUE),.os_call_sites),recursive=FALSE)
 keep<-function(cl) {bits<-strsplit(cl$fn,'::',fixed=TRUE)[[1]];any(vapply(sites,function(s)identical(s$fn,bits[2])&&(is.na(s$pkg)||identical(s$pkg,bits[1])),FALSE))}
 moved<-Filter(function(cl)!keep(cl),reg$calls);reg$calls<-Filter(keep,reg$calls)
 reg$moved_to_shared<-lapply(moved,function(cl)list(fn=cl$fn,reason='shared model input/output/figure implementation',source='skills/_shared/scripts'))
 jsonlite::write_json(reg,p,auto_unbox=TRUE,pretty=TRUE,null='null')
}
