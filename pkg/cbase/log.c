#include <stdio.h>
#include <time.h>
#include <sys/time.h>

char* log_get_current_time() {
  static char time_str[13];
  struct timeval tv;
  struct tm* tm_info;

  gettimeofday(&tv, NULL);
  tm_info = gmtime(&tv.tv_sec);

  snprintf(time_str, sizeof(time_str), "%02d:%02d:%02d.%03ld",
           tm_info->tm_hour, tm_info->tm_min, tm_info->tm_sec, tv.tv_usec / 1000);

  return time_str;
}

