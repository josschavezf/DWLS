#' @title Build Signature matrix using MAST given a differential expression
#' matrix
#'
#' @description This function builds a signature matrix using a pre-created
#' differential expression matrix. The input matrix must have the same format
#' as the DEAnalysisMAST() function and must be saved as an RData file
#' ending with _MIST. The file must be named identity_MIST.RData.
#' See exampledata_MIST.RData for more information (inst/man).
#'
#' @param scdata The data
#' @param id The identities of the genes
#' @param path The path to the file results
#' @param diff.cutoff This is automatically set to 0.5
#' @param pval.cutoff This is automatically set to 0.01
#'
#' @return Signature Matrix built using the MAST algorithm
#'
#' @examples
#'
#' \donttest{
#' #dataSC
#' url <- "https://github.com/sistia01/DWLS/raw/main/inst/extdata/dataSC.RData"
#' dest <- "data/dataSC.RData"
#' download.file(url, dest)
#' load("data/dataSC.RData")
#'
#' #dataBulk
#' url <- "https://github.com/sistia01/DWLS/raw/main/inst/extdata/dataBulk.RData"
#' dest <- "data/dataBulk.RData"
#' download.file(url, dest)
#' load("data/dataBulk.RData")
#'
#' #labels
#' url <- "https://github.com/sistia01/DWLS/raw/main/inst/extdata/labels.RData"
#' dest <- "data/labels.RData"
#' download.file(url, dest)
#' load("data/labels.RData")
#'
#' #data('trueLabels', package = "DWLS")
#' url <- "https://github.com/sistia01/DWLS/raw/main/inst/extdata/trueLabels.RData"
#' dest <- "data/trueLabels.RData"
#' download.file(url, dest)
#' load("data/trueLabels.RData")
#'
#' labels<-trueLabels
#'
#' #Change to real labels
#' newcat<-c("NonCycISC","CycISC","TA","Ent","PreEnt","Goblet",
#' "Paneth","Tuft","EE")
#' for (i in 1:length(newcat)){
#'   labels[which(labels==(i-1))]<-newcat[i]
#'   }
#' #Results in inst/extdata/results -- run on local
#' #Signature<-buildSignatureMatrixMAST(dataSC,labels,"results",
#' # diff.cutoff=0.5,pval.cutoff=0.01)
#'}
#'
#' @export MASTSignatureMatrixGivenDE
#'
#' @importFrom dplyr "%>%"
#' @importFrom stats "p.adjust"


MASTSignatureMatrixGivenDE<-function(scdata,id,path,
                                   diff.cutoff=0.5,pval.cutoff=0.01)
  #DEAnalysisMAST(scdata,id,path)
  { numberofGenes<-c()
  for (i in unique(id)){
    if(file.exists(paste(path,"/",i,"_MIST.RData", sep=""))){
      load(file=paste(path,"/",i,"_MIST.RData", sep=""))
      pvalue_adjusted<-p.adjust(cluster_lrTest.table[,3], method = "fdr",
                                n = length(cluster_lrTest.table[,3]))
      cluster_lrTest.table<-cbind(cluster_lrTest.table,pvalue_adjusted)
      DEGenes<-cluster_lrTest.table$Gene[intersect(which
                      (pvalue_adjusted<pval.cutoff),
                      which(cluster_lrTest.table$log2fold_change>diff.cutoff))]
      nonMir = grep("MIR|Mir", DEGenes, invert = T)
      assign(paste("cluster_lrTest.table.",i,sep=""),
    cluster_lrTest.table[which(cluster_lrTest.table$Gene%in%DEGenes[nonMir]),])
      numberofGenes<-c(numberofGenes,length(DEGenes[nonMir]))
    }
  }
  #need to reduce number of genes
  #for each subset, order significant genes by decreasing fold change,
  #choose between 50 and 200 genes
  #for each, iterate and choose matrix with lowest condition number
  conditionNumbers<-c()
  for(G in 50:200){
    Genes<-c()
    j=1
    for (i in unique(id)){
      if(numberofGenes[j]>0){
        temp<-paste("cluster_lrTest.table.",i,sep="")
        temp<-as.name(temp)
        temp<-eval(parse(text = temp))
        temp<-temp[order(temp$log2fold_change,decreasing=TRUE),]
        Genes<-c(Genes,varhandle::unfactor(temp$Gene[1:min(G,
                                                           numberofGenes[j])]))
      }
      j=j+1
    }
    Genes<-unique(Genes)
    #make signature matrix
    ExprSubset<-scdata[Genes,]
    Sig<-NULL
    for (i in unique(id)){
      Sig<-cbind(Sig,(apply(ExprSubset,1,function(y) mean(y[which(id==i)]))))
    }
    colnames(Sig)<-unique(id)
    conditionNumbers<-c(conditionNumbers,kappa(Sig))
  }
  G<-which.min(conditionNumbers)+min(49,numberofGenes-1)
  Genes<-c()
  j=1
  for (i in unique(id)){
    if(numberofGenes[j]>0){
      temp<-paste("cluster_lrTest.table.",i,sep="")
      temp<-as.name(temp)
      temp<-eval(parse(text = temp))
      temp<-temp[order(temp$log2fold_change,decreasing=TRUE),]
      Genes<-c(Genes,varhandle::unfactor(temp$Gene[1:min(G,numberofGenes[j])]))
    }
    j=j+1
  }
  Genes<-unique(Genes)
  ExprSubset<-scdata[Genes,]
  Sig<-NULL
  for (i in unique(id)){
    Sig<-cbind(Sig,(apply(ExprSubset,1,function(y) mean(y[which(id==i)]))))
  }
  colnames(Sig)<-unique(id)
  save(Sig,file=paste(path,"/Sig.RData",sep=""))
  saveRDS(Sig,file=paste(path,"/Sig.rds",sep=""))
  return(Sig)
}

