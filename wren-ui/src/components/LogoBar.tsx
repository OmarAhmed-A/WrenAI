import Image from 'next/image';

export default function LogoBar() {
  return (
    <Image
      src="/images/raisaImg.png"
      alt="Raisa AI"
      width={65}
      height={30}
      className="bg-white blur-sm rounded"
    />
  );
}
