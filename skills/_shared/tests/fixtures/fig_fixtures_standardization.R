fx_standardization_builders <- function(journal = NULL) {
  curves <- data.frame(time = rep(0:4, 2), survival = c(1,.9,.8,.7,.6,1,.95,.9,.85,.8), group = rep(c("A", "B"), each = 5), n_censor = c(0,1,0,0,0,0,0,1,0,0))
  risk <- data.frame(time = rep(c(0,2,4),2), n_risk = c(20,16,10,20,18,15), group = rep(c("A","B"),each=3))
  hr <- data.frame(term = c("Marker A","Marker B"), estimate = c(.7,1.5), ci_low = c(.5,1.1), ci_high = c(.9,2))
  roc <- data.frame(fpr = rep(c(0,.2,.5,1),2), tpr = c(0,.6,.8,1,0,.5,.7,1), horizon = rep(c("12","24"),each=4))
  path <- data.frame(lambda = rep(c(.01,.1,1),2), coefficient = c(.6,.3,0,-.4,-.2,0), feature = rep(c("A","B"),each=3))
  cal <- data.frame(predicted = c(.1,.3,.6,.8), observed = c(.12,.28,.65,.78))
  group <- data.frame(group = rep(c("Control","Treated"),each=5), value = c(1,1.2,.8,1.1,.9,1.5,1.7,1.4,1.6,1.8), unit = paste0("U",1:10))
  cmp <- data.frame(group1="Control", group2="Treated",p=.03,y=2)
  obs <- data.frame(dose = c(.1,1,10,100), response = c(.05,.25,.75,.95))
  grid <- data.frame(dose = 10^seq(-1,2,length.out=101)); grid$predicted <- grid$dose/(grid$dose+3)
  list(km = function() os_km(curves,risk,"months",.04,journal),
       hr = function() os_hr_forest(hr,.95,journal),
       time_roc = function() os_time_roc(roc,"months",journal),
       lasso = function() os_lasso_path(path,.1,journal),
       calibration = function() os_calibration(cal,24,"months",journal),
       group_box = function() os_group_points(group,"unit","Expression","box",cmp,"Welch t",journal=journal),
       group_bar = function() os_group_points(group,"unit","Response","bar",journal=journal),
       standard_curve = function() os_standard_curve(obs,grid,"ng/mL","4PL",.2,50,journal))
}
