FROM rocker/geospatial:4.2.2

# 日本語ロケールの設定
ENV LANG ja_JP.UTF-8
ENV LC_ALL ja_JP.UTF-8
RUN sed -i '$d' /etc/locale.gen \
  && echo "ja_JP.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen ja_JP.UTF-8 \
    && /usr/sbin/update-locale LANG=ja_JP.UTF-8 LANGUAGE="ja_JP:ja"
RUN /bin/bash -c "source /etc/default/locale"
RUN ln -sf  /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# 日本語フォントのインストール
RUN apt-get update && apt-get install -y \
  fonts-ipaexfont \
  fonts-noto-cjk

# ワーキングディレクトリの設定
RUN echo "setwd(\"/home/rstudio/workspace/\")" > /home/rstudio/.Rprofile

# rocker/geospatialに含まれないRPackageのインストール
# CRANからのインストール
RUN install2.r -d TRUE -e -n -1 \
  celestial
# GitHubからのインストール
RUN installGithub.r \
  uribo/jpmesh \
  uribo/jpndistrict

# インストール時にダウンロードした一時ファイルの削除
RUN rm -rf /tmp/downloaded_packages/ /tmp/*.rds
