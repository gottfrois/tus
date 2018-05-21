# Elixir tus

[![travis.ci build status](https://img.shields.io/travis/jpscaletti/tus.svg?style=flat)](https://travis-ci.org/jpscaletti/tus)

An implementation of a *[tus](https://tus.io/)* **server** in Elixir

**Documentation: https://hexdocs.pm/tus/**

<img alt="Tus logo" src="https://github.com/tus/tus.io/blob/master/assets/img/tus1.png?raw=true" width="30%" align="right" />

> **tus** is a protocol based on HTTP for *resumable file uploads*. Resumable
> means that an upload can be interrupted at any moment and can be resumed without
> re-uploading the previous data again.
>
> An interruption may happen willingly, if the user wants to pause,
> or by accident in case of an network issue or server outage.

It's currently capable of accepting uploads with arbitrary sizes and storing them locally
on disk; or in Amazon S3, by installing the [`tus_storage_s3`](https://hex.pm/packages/tus_storage_s3) hex package.
Due to its modularization and extensibility, support for any other cloud provider can be easily added.

## Features

This library implements the core TUS API v1.0.0 protocol and the following extensions:

- Creation Protocol (http://tus.io/protocols/resumable-upload.html#creation). Deferring the upload's length is not possible.
- Termination Protocol (http://tus.io/protocols/resumable-upload.html#termination)

