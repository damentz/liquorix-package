from collections import OrderedDict

__all__ = ("KconfigFile",)


class KConfigEntry:
    __slots__ = "comments", "name", "value"

    def __init__(self, name, value, comments=None):
        self.name, self.value = name, value
        self.comments = comments or []

    def __eq__(self, other):
        return self.name == other.name and self.value == other.value

    def __hash__(self):
        return hash(self.name) | hash(self.value)

    def __repr__(self):
        return f"<{self.__class__.__name__}({self.name!r}, {self.value!r}, {self.comments!r})>"

    def __str__(self):
        return f"CONFIG_{self.name}={self.value}"

    def write(self):
        for comment in self.comments:
            yield "#. " + comment
        yield str(self)


class KConfigEntryTristate(KConfigEntry):
    __slots__ = ()

    VALUE_NO = False
    VALUE_YES = True
    VALUE_MOD = object()

    def __init__(self, name, value, comments=None):
        if value == "n" or value is None:
            value = self.VALUE_NO
        elif value == "y":
            value = self.VALUE_YES
        elif value == "m":
            value = self.VALUE_MOD
        else:
            raise NotImplementedError
        super().__init__(name, value, comments)

    def __str__(self):
        if self.value is self.VALUE_MOD:
            return f"CONFIG_{self.name}=m"
        if self.value:
            return f"CONFIG_{self.name}=y"
        return f"# CONFIG_{self.name} is not set"


class KconfigFile(OrderedDict):
    def __str__(self):
        return "\n".join(self.str_iter()) + "\n"

    def read(self, f):
        for line in iter(f.readlines()):
            line = line.strip()
            if line.startswith("CONFIG_"):
                i = line.find("=")
                option = line[7:i]
                value = line[i + 1 :]
                self.set(option, value)
            elif line.startswith("# CONFIG_"):
                option = line[9:-11]
                self.set(option, "n")
            elif line.startswith("#") or not line:
                pass
            else:
                raise RuntimeError(f"Can't recognize {line}")

    def set(self, key, value):
        if value in ("y", "m", "n"):
            entry = KConfigEntryTristate(key, value)
        else:
            entry = KConfigEntry(key, value)
        self[key] = entry

    def str_iter(self):
        for value in self.values():
            yield str(value)
