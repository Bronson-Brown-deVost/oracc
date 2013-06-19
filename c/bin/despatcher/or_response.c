#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "resolver.h"

const char *mode = "full";
const char *perlprog = NULL;
const char *xtf2html = "/usr/local/oracc/lib/scripts/g2-xtf-HTML.xsl";
const char *stats_html = "/usr/local/oracc/lib/scripts/stats-HTML.xsl";

void
adhoc(const char *adhoc_texts, const char *line_id, const char *frag_id)
{
  /* print_hdr_xml(); */
  if (!line_id)
    line_id = "none";
  if (!frag_id)
    frag_id = "none";
  execl("/usr/bin/perl", "perl", "/usr/local/oracc/bin/p3-pager.plx", 
	cgi_arg("project", project),
	cgi_arg("adhoc", adhoc_texts),
	cgi_arg("line-id", line_id),
	cgi_arg("frag-id", frag_id),
	cgi_arg("mode", mode),
	NULL);
  perror("execl failed");
  exit(1);
}

void
cat_file(const char *file)
{
  print_hdr_xml();
  fprintf(stderr,"oracc-despatcher/cat_file: %s\n", file);
  execl("/bin/cat", "cat", file, NULL);
  perror("execl failed");
}

void
cat_html_file(const char *file)
{
  print_hdr();
  fprintf(stderr,"oracc-despatcher/cat_html_file: %s\n", file);
  execl("/bin/cat", "cat", file, NULL);
  perror("execl failed");
}

void
cat_index_html(const char *dir)
{
  char *buf = NULL, *slash = "";

  if (dir)
    {
      if (dir[strlen(dir)-1] != '/')
	slash = "/";
    }
  else
    slash = "/";

  buf = malloc(strlen(docroot) + strlen(dir) + strlen("index.html") + 3);
  sprintf(buf, "%s/%s/index.html", docroot, dir);
  cat_html_file(buf);
}

void
corpus(void)
{
  if (project)
    {
      char *p3init = malloc(1+strlen(project)+strlen("/usr/local/oracc/www/%s/p3init.html"));
      sprintf(p3init, "/usr/local/oracc/www/%s/p3init.html", project);
      if (!access(p3init,R_OK))
	{
	  cat_html_file(p3init);
	}
      else
	{
	  free(p3init);
	  do404();
	}
    }
  else
    cat_html_file("/usr/local/oracc/www/corpus.html");
}

void
progexec(const char *prog)
{
  execl("/usr/bin/perl", "perl", prog, NULL);
}

void
itemmain(const char *session, const char *list)
{
  static char buf[1024];
  sprintf(buf,"/var/tmp/oracc/pager/%s/%s/itemmain.html",session,list);
  cat_file(buf);
}

void
itemside(const char *session, const char *list)
{
  static char buf[1024];
  sprintf(buf,"/var/tmp/oracc/pager/%s/%s/itemside.html",session,list);
  cat_file(buf);
}

void
outline(const char *session, const char *list)
{
  static char buf[1024];
  sprintf(buf,"/var/tmp/oracc/pager/%s/%s/outline.html",session,list);
  cat_file(buf);
}

void
results(const char *session, const char *list)
{
  static char buf[1024];
  sprintf(buf,"/var/tmp/oracc/pager/%s/%s/results.html",session,list);
  cat_file(buf);
}

void
sigfixer(const char *file)
{
  execl("/usr/local/oracc/bin/sigfixer", "sigfixer", project, file, NULL);
  perror("execl failed");
}

void
sigfixer_html(const char *file)
{
  print_hdr();
  execl("/usr/local/oracc/bin/sigfixer", "sigfixer", project, file, NULL);
  perror("execl failed");
}

void
statistics(void)
{
  if (project)
    {
      char *data;
      data = malloc(strlen(project) + strlen("/usr/local/oracc/xml//project-data.xml") + 1);
      sprintf(data, "/usr/local/oracc/xml/%s/project-data.xml", project);
      print_hdr();
      execl("/usr/bin/xsltproc", "xsltproc", stats_html, data, NULL);
      do404();
    }
  else
    do404();
}

void
sig(const char *sig)
{
  fprintf(stderr, "oracc-despatcher: project=`%s'; literal sig=`%s'\n", project, query_string);
  execl("/usr/local/oracc/bin/sigmap", "sigmap", project, query_string, NULL);
  perror("execl failed");
}

void
tei(const char *item)
{
  char buf[1024];
  sprintf(buf,"/usr/local/oracc/www/%s/tei/%s.xml",project,item);
  print_hdr_xml();
  fflush(stdout);
  execl("/bin/cat", "cat", buf, NULL);
  perror("execl failed");
}

void
xis(const char *xlang, const char *xid)
{
  execl("/usr/bin/perl", "perl", "/usr/local/oracc/bin/p3-pager.plx", 
	cgi_arg("project", project), 
	cgi_arg("glos", xlang),
	cgi_arg("gxis", xid),
	NULL);
  perror("execl failed");
  exit(1);
}

void
list(const char *list)
{
  execl("/usr/bin/perl", "perl", "/usr/local/oracc/bin/p3-pager.plx", 
	cgi_arg("project", project),
	cgi_arg("list", list),
	cgi_arg("mode", mode),
	NULL);
  perror("execl failed");
  exit(1);
}

void
sed_project(const char *xml, const char *session)
{
  char expr1[512], expr2[512];
  sprintf(expr1,"s%%@@PROJECT@@%%%s%%g",project);
  sprintf(expr2,"s/@@SESSION@@/%s/g",session);
  print_hdr_xml();
  fflush(stdout);
  execl("/bin/sed", "sed", "-e" , expr1, "-e", expr2, xml, NULL);
  perror("execl failed");
}
