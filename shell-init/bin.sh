case :$PATH: in
    *:"@SRC@/bin":*) ;;
    *) export PATH="@SRC@/bin:$PATH" ;;
esac
